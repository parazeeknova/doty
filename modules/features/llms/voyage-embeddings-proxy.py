"""
Voyage AI <-> OpenAI embeddings translation proxy for supermemory local.

Why this exists
---------------
supermemory's `openai` embedding provider speaks the OpenAI embeddings dialect,
but Voyage's endpoint is only *partly* OpenAI-compatible. Observed mismatches:

  1. supermemory sends `"encoding_format": "float"`. Voyage rejects it:
       400 Value 'float' supplied for argument 'encoding_format' is not valid
           -- accepted values are 'base64'
     So we strip it and let Voyage return its native float arrays, which is
     exactly what the OpenAI client expects anyway.

  2. supermemory never sends a `dimensions` field -- it sizes its own vectors
     from SUPERMEMORY_EMBEDDING_DIMENSIONS and trusts the provider to match.
     Voyage would then silently return its 1024 default, so
     VOYAGE_OUTPUT_DIMENSION pins the width explicitly. Left unset, a 2048d
     config would quietly store 1024d vectors.

  3. OpenAI uses `dimensions`; Voyage uses `output_dimension`. We translate if
     a caller sends it, but the env default is what actually applies.

  4. Voyage's `usage` omits `prompt_tokens`, which some OpenAI clients read.
     We synthesize it from `total_tokens`.

Rate limiting and request coalescing
------------------------------------
Voyage's *unpaid* tier is only 3 requests/minute and 10K tokens/minute. Two
constraints made naive proxying fail there:

  * supermemory times an embedding call out after a hardcoded 20s, and
  * supermemory fires one request per text, concurrently.

Serialising those at 3 RPM would push waits past 20s and every call would
fail. So instead of one upstream call per inbound call, this proxy *coalesces*:
concurrent inbound requests are merged into a single Voyage call carrying many
inputs, and the response is split back out. That turns N requests into roughly
ceil(N / VOYAGE_MAX_BATCH), which keeps the wait per call small.

Pacing defaults to OFF (VOYAGE_MAX_RPM / VOYAGE_MAX_TPM = 0), because this
account's limits were raised well above the unpaid tier -- measured at 200
requests / 20-way parallel and a 32k-token batch without a single 429. Coalescing
and 429/5xx retry-with-backoff stay on as the safety net, so a lowered limit
degrades into slow successes rather than hard failures. If you ever fall back to
an unpaid key, set VOYAGE_MAX_RPM=3 and VOYAGE_MAX_TPM=10000 to pace instead of
relying on retries.

We deliberately do NOT set `input_type`. Voyage recommends `query` vs
`document`, but supermemory funnels both through one URL with no marker, and
Voyage documents that vectors made with and without `input_type` are
compatible. Guessing per-request would be worse than omitting it.
"""
import json
import os
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

UPSTREAM = os.environ.get("VOYAGE_UPSTREAM", "https://api.voyageai.com").rstrip("/")
PORT = int(os.environ.get("VOYAGE_PROXY_PORT", "6797"))
LOG_PATH = os.environ.get("VOYAGE_PROXY_LOG", "")

# Pacing is off by default: this account's limits are well above Voyage's
# unpaid tier (measured 200 requests / 20-way parallel and a 32k-token batch
# with no 429s). Retry-with-backoff below still absorbs any 429. To run on an
# unpaid key, set VOYAGE_MAX_RPM=3 and VOYAGE_MAX_TPM=10000.
MAX_RPM = int(os.environ.get("VOYAGE_MAX_RPM", "0"))
MAX_TPM = int(os.environ.get("VOYAGE_MAX_TPM", "0"))
MAX_ATTEMPTS = int(os.environ.get("VOYAGE_MAX_ATTEMPTS", "6"))
MAX_BATCH = int(os.environ.get("VOYAGE_MAX_BATCH", "128"))
OUTPUT_DIMENSION = int(os.environ.get("VOYAGE_OUTPUT_DIMENSION", "0"))

# How long a request may wait for company before we send the batch, and the
# overall deadline for a caller. supermemory gives up at 20s, so stay under it.
COALESCE_WINDOW = float(os.environ.get("VOYAGE_COALESCE_WINDOW", "0.35"))
CLIENT_DEADLINE = float(os.environ.get("VOYAGE_CLIENT_DEADLINE", "17.0"))

_lock = threading.Lock()
_req_times = []
_token_times = []
_pending = []          # list of _Job waiting to be batched
_wake = threading.Event()


def api_key():
    key = os.environ.get("VOYAGE_API_KEY", "")
    if not key and os.path.exists("/run/secrets/voyage-api-key"):
        with open("/run/secrets/voyage-api-key") as f:
            key = f.read().strip()
    return key


def log(line):
    if LOG_PATH:
        try:
            with open(LOG_PATH, "a") as f:
                f.write(line + "\n")
        except OSError:
            pass


def estimate_tokens(texts):
    """Rough token estimate (~4 chars/token), used only for pacing."""
    return max(sum(len(t) // 4 + 1 for t in texts), 1)


def _prune(now):
    cutoff = now - 60.0
    while _req_times and _req_times[0] < cutoff:
        _req_times.pop(0)
    while _token_times and _token_times[0][0] < cutoff:
        _token_times.pop(0)


def _reserve(est_tokens):
    """
    Reserve budget for one upstream call.

    Returns the number of seconds the caller should wait, or 0 if the call may
    proceed immediately. The caller sleeps *outside* the lock so other requests
    can still be coalesced while it waits.
    """
    if MAX_RPM <= 0 and MAX_TPM <= 0:
        return 0.0
    now = time.time()
    _prune(now)
    used = sum(t for _, t in _token_times)
    if MAX_RPM > 0 and len(_req_times) >= MAX_RPM:
        return max(_req_times[0] + 60.0 - now, 0.0)
    if MAX_TPM > 0 and _token_times and used + est_tokens > MAX_TPM:
        return max(_token_times[0][0] + 60.0 - now, 0.0)
    _req_times.append(now)
    _token_times.append((now, est_tokens))
    return 0.0


class _Job:
    """One inbound request's worth of texts, awaiting a shared upstream call."""

    __slots__ = ("texts", "slots", "next_slot", "outstanding", "prefix",
                 "result", "error", "event")

    def __init__(self, texts, prefix):
        self.texts = list(texts)      # texts not yet handed to an upstream call
        self.slots = {}               # slot index -> vector
        self.next_slot = 0            # slot to assign to the next text handed out
        self.outstanding = 0          # texts in flight, awaiting a response
        self.prefix = prefix          # non-input fields for the upstream call
        self.result = None
        self.error = None
        self.event = threading.Event()


def _prefix_key(prefix):
    return json.dumps(prefix, sort_keys=True)


def _post_embeddings(payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        UPSTREAM + "/v1/embeddings",
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer " + api_key(),
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=100) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except Exception as e:
        return 502, json.dumps({"error": str(e)}).encode()


def _finish(job, code, msg):
    job.error = (code, msg)
    job.event.set()


def _worker():
    """
    Collect pending jobs, merge compatible ones, and issue shared Voyage calls.

    Jobs are only merged when their non-input fields match, so a 1024d request
    can never be batched with a 2048d one. A job whose texts exceed the batch
    cap keeps its identity across rounds and accumulates vectors, which is what
    lets the waiting caller stay blocked on a single event.
    """
    while True:
        _wake.wait()
        _wake.clear()
        time.sleep(COALESCE_WINDOW)   # let a few more requests pile in

        with _lock:
            jobs, _pending[:] = list(_pending), []

        if not jobs:
            continue

        # Group by identical upstream parameters.
        groups = {}
        for job in jobs:
            groups.setdefault(_prefix_key(job.prefix), []).append(job)

        for key, group in groups.items():
            texts, owners, slots = [], [], []
            leftover = []
            for job in group:
                # Only hand over texts not already in flight. A job split
                # across rounds must not resend what it already submitted, or
                # it would accumulate duplicate vectors.
                available = job.texts
                if not available:
                    continue
                if len(texts) >= MAX_BATCH:
                    leftover.append(job)
                    continue
                room = MAX_BATCH - len(texts)
                take = available[:room]
                texts.extend(take)
                owners.extend([job] * len(take))
                # Remember each text's position in the caller's original list,
                # so vectors can be reordered correctly even when a job is
                # split across several upstream calls.
                slots.extend(range(job.next_slot, job.next_slot + len(take)))
                job.next_slot += len(take)
                job.texts = available[len(take):]
                job.outstanding += len(take)
                if job.texts:
                    leftover.append(job)

            if leftover:
                with _lock:
                    _pending.extend(leftover)
                _wake.set()

            if not texts:
                continue

            base = dict(group[0].prefix)
            base["input"] = texts

            wait = _reserve(estimate_tokens(texts))
            if wait > 0:
                time.sleep(wait)

            code, out = None, b"{}"
            for attempt in range(1, MAX_ATTEMPTS + 1):
                code, out = _post_embeddings(base)
                log("batch %d texts -> %s (attempt %d)" % (len(texts), code, attempt))
                if code < 400 or code == 400:
                    break
                if code in (429, 500, 502, 503, 504) and attempt < MAX_ATTEMPTS:
                    time.sleep(min(2 ** attempt, 30))
                    continue
                break

            if code is not None and code >= 400:
                msg = out[:300].decode("utf-8", "replace")
                for job in set(owners):
                    _finish(job, code, msg)
                continue

            try:
                parsed = json.loads(out.decode("utf-8"))
                vectors = [d.get("embedding") for d in parsed.get("data", [])]
                usage = parsed.get("usage") or {}
                if "total_tokens" in usage and "prompt_tokens" not in usage:
                    usage["prompt_tokens"] = usage["total_tokens"]
            except Exception as e:
                for job in set(owners):
                    _finish(job, 502, "bad upstream response: %s" % e)
                continue

            if len(vectors) != len(texts):
                for job in set(owners):
                    _finish(job, 502, "expected %d vectors, got %d" % (len(texts), len(vectors)))
                continue

            # Hand each vector back to its owning job, at the slot it was requested in.
            for vec, job, slot in zip(vectors, owners, slots):
                job.slots[slot] = vec
                job.outstanding -= 1

            # A job is done only when nothing is left to send or in flight.
            for job in set(owners):
                if not job.texts and job.outstanding <= 0 and job.error is None:
                    ordered = [job.slots[i] for i in range(job.next_slot)]
                    job.result = {
                        "object": "list",
                        "data": [
                            {"object": "embedding", "index": i, "embedding": v}
                            for i, v in enumerate(ordered)
                        ],
                        "model": base.get("model", "voyage-4-large"),
                        "usage": dict(usage),
                    }
                    job.event.set()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, code, payload):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)

        try:
            body = json.loads(raw.decode("utf-8"))
        except Exception:
            self._send(400, json.dumps({"error": "invalid JSON body"}).encode())
            return

        # --- translate OpenAI dialect -> Voyage dialect -------------------
        body.pop("encoding_format", None)
        if "dimensions" in body:
            body["output_dimension"] = body.pop("dimensions")
        elif OUTPUT_DIMENSION > 0:
            body["output_dimension"] = OUTPUT_DIMENSION
        for junk in ("user", "extra_body"):
            body.pop(junk, None)

        raw_input = body.pop("input", [])
        texts = [raw_input] if isinstance(raw_input, str) else list(raw_input)
        if not texts:
            self._send(400, json.dumps({"error": "no input supplied"}).encode())
            return

        job = _Job(texts, body)
        with _lock:
            _pending.append(job)
        _wake.set()

        if not job.event.wait(CLIENT_DEADLINE):
            self._send(504, json.dumps({
                "error": "timed out waiting for rate-limit budget",
            }).encode())
            return
        if job.error:
            code, msg = job.error
            self._send(code, json.dumps({"error": msg}).encode())
            return

        self._send(200, json.dumps(job.result).encode("utf-8"))

    def do_GET(self):
        # Some OpenAI clients probe /models; report the one model we serve.
        if self.path.rstrip("/").endswith("/models"):
            self._send(200, json.dumps({
                "object": "list",
                "data": [{
                    "id": "voyage-4-large",
                    "object": "model",
                    "owned_by": "voyageai",
                }],
            }).encode())
            return
        self._send(404, json.dumps({"error": "not found"}).encode())

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    threading.Thread(target=_worker, daemon=True).start()
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()