#!/usr/bin/env python3
"""
Export / restore supermemory local content.

Why this is needed
------------------
supermemory locks its embedding plan into the data dir and REFUSES to boot when
the configured provider/model/dimensions disagree with stored vectors:

    Embedding model mismatch: this data dir already has embeddings from
      locked:     google · gemini-embedding-2 · 1536d
      configured: openai · voyage-4-large · 1024d

So switching embedding models is not an in-place operation -- the data dir must
be wiped. This tool snapshots everything worth keeping first, and can put it
back afterwards.

What is captured
----------------
  documents  full text/URL content per container tag (v3/documents/list with
             includeContent), so ingestion can be replayed
  memories   every memory entry per container tag (v4/memories/list), which
             can be re-created directly without paying for re-extraction

Usage
-----
  ./sm-export.py backup  <out.json>
  ./sm-export.py restore <in.json> [--memories-only|--documents-only]
  ./sm-export.py verify  <out.json>
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("SUPERMEMORY_BASE_URL", "http://localhost:6767").rstrip("/")


def api_key():
    key = os.environ.get("SUPERMEMORY_API_KEY", "")
    if not key:
        for path in ("/run/secrets/supermemory-api-key",
                     os.path.expanduser("~/.supermemory/api-key")):
            if os.path.exists(path):
                with open(path) as f:
                    key = f.read().strip()
                if key:
                    break
    return key


KEY = api_key()


def call(path, payload=None, method="POST", timeout=120):
    url = BASE + path
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        url, data=data, method=method,
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            body = r.read()
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {path} -> {e.code}: {e.read()[:300].decode('utf-8','replace')}")
    return json.loads(body) if body else {}


def flatten_metadata(meta):
    """
    Coerce metadata into the flat shape /v4/memories accepts.

    The API only permits string/number/boolean/array values. Exported memories
    can carry nested objects (notably `temporalContext`), and re-posting those
    verbatim fails with:

        path: ["memories", 8, "metadata", "temporalContext"]
        message: "Invalid input: expected string, received object"

    Nested values are JSON-encoded rather than dropped, so nothing is lost.
    """
    if not isinstance(meta, dict):
        return {}
    flat = {}
    for k, v in meta.items():
        if v is None:
            continue
        if isinstance(v, (str, int, float, bool)):
            flat[k] = v
        elif isinstance(v, list) and all(isinstance(i, (str, int, float, bool)) for i in v):
            flat[k] = v
        else:
            flat[k] = json.dumps(v)
    return flat


def container_tags():
    data = call("/v3/container-tags/list", method="GET")
    if isinstance(data, dict):
        data = data.get("containerTags") or data.get("data") or []
    return [t.get("containerTag") for t in data if t.get("containerTag")]


def list_documents(tag):
    """Page through every document in a container tag."""
    out, page = [], 1
    while True:
        d = call("/v3/documents/list", {
            "containerTags": [tag], "limit": 100, "page": page, "includeContent": True,
        })
        items = d.get("memories") or d.get("documents") or []
        out.extend(items)
        pg = d.get("pagination") or {}
        if page >= (pg.get("totalPages") or 1) or not items:
            break
        page += 1
    return out


def list_memories(tag):
    out, page = [], 1
    while True:
        d = call("/v4/memories/list", {"containerTags": [tag], "limit": 100, "page": page})
        items = d.get("memoryEntries") or d.get("memories") or []
        out.extend(items)
        pg = d.get("pagination") or {}
        if page >= (pg.get("totalPages") or 1) or not items:
            break
        page += 1
    return out


def cmd_backup(args):
    tags = container_tags()
    print(f"container tags: {len(tags)}")
    snap = {"base": BASE, "containerTags": {}}
    for tag in tags:
        docs = list_documents(tag)
        mems = list_memories(tag)
        snap["containerTags"][tag] = {"documents": docs, "memories": mems}
        print(f"  {tag:45s} docs={len(docs):3d} mems={len(mems):4d}")
    with open(args.file, "w", encoding="utf-8") as f:
        json.dump(snap, f, indent=2)
    total_d = sum(len(v["documents"]) for v in snap["containerTags"].values())
    total_m = sum(len(v["memories"]) for v in snap["containerTags"].values())
    print(f"wrote {args.file}: {total_d} documents, {total_m} memories")


def cmd_verify(args):
    with open(args.file, encoding="utf-8") as f:
        snap = json.load(f)
    td = tm = twc = 0
    for tag, v in snap["containerTags"].items():
        docs, mems = v["documents"], v["memories"]
        wc = sum(1 for d in docs if d.get("content") or d.get("url"))
        td += len(docs); tm += len(mems); twc += wc
        print(f"  {tag:45s} docs={len(docs):3d} (recoverable={wc:3d}) mems={len(mems):4d}")
    print(f"total: {td} documents ({twc} recoverable), {tm} memories")


def cmd_restore(args):
    with open(args.file, encoding="utf-8") as f:
        snap = json.load(f)
    for tag, v in snap["containerTags"].items():
        if args.mode in ("all", "documents"):
            docs = [d for d in v["documents"] if d.get("content") or d.get("url")]
            for i in range(0, len(docs), 50):
                batch = [{
                    "content": d.get("content") or d.get("url"),
                    "containerTag": tag,
                    "customId": d.get("customId"),
                    "metadata": d.get("metadata") or {},
                } for d in docs[i:i + 50]]
                if batch:
                    call("/v3/documents/batch", {"documents": batch})
                    print(f"  {tag}: re-ingested {len(batch)} documents")
        if args.mode in ("all", "memories"):
            mems = [{"content": m.get("memory") or m.get("content"),
                     "metadata": flatten_metadata(m.get("metadata"))}
                    for m in v["memories"]]
            mems = [m for m in mems if m["content"]]
            for i in range(0, len(mems), 20):
                batch = mems[i:i + 20]
                if batch:
                    call("/v4/memories", {"containerTag": tag, "memories": batch})
                    print(f"  {tag}: re-created {len(batch)} memories")
    print("restore complete")


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("backup"); b.add_argument("file"); b.set_defaults(fn=cmd_backup)
    v = sub.add_parser("verify"); v.add_argument("file"); v.set_defaults(fn=cmd_verify)
    r = sub.add_parser("restore"); r.add_argument("file")
    r.add_argument("--mode", choices=["all", "documents", "memories"], default="all")
    r.set_defaults(fn=cmd_restore)
    args = p.parse_args()
    if not KEY:
        sys.exit("no supermemory API key found")
    args.fn(args)


if __name__ == "__main__":
    main()