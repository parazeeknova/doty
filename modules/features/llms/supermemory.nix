{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaSupermemory =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      supermemory-server = pkgs.stdenv.mkDerivation rec {
        pname = "supermemory-server";
        version = "0.0.8";

        src = pkgs.fetchurl {
          url = "https://github.com/supermemoryai/supermemory/releases/download/server-v${version}/supermemory-server-linux-x64";
          sha256 = "1wq6amxsglcbrdza4hj368l43bv5mkxvm8fqp45yi6qps0rj9ww7";
        };

        dontUnpack = true;
        dontStrip = true;
        dontPatchELF = true;

        installPhase = ''
          install -m755 -D $src $out/bin/supermemory-server
        '';

        meta = {
          description = "Supermemory local persistent memory server";
          homepage = "https://github.com/supermemoryai/supermemory";
          platforms = [ "x86_64-linux" ];
          mainProgram = "supermemory-server";
        };
      };

      # Python failover proxy for General Compute:
      # Primary: deepseek-v3.2, Fallback: minimax-m2.7
      gcProxyScript = pkgs.writeScript "supermemory-gc-proxy.py" ''
        #!${pkgs.python3}/bin/python3
        import os, sys, json, urllib.request, urllib.error
        from http.server import HTTPServer, BaseHTTPRequestHandler

        PORT = int(os.environ.get("GC_PROXY_PORT", "6768"))
        UPSTREAM_BASE = os.environ.get("GC_UPSTREAM_URL", "https://api.generalcompute.com/v1").rstrip("/")
        PRIMARY_MODEL = os.environ.get("GC_PRIMARY_MODEL", "deepseek-v3.2")
        FALLBACK_MODEL = os.environ.get("GC_FALLBACK_MODEL", "minimax-m2.7")

        def get_api_key():
            key = os.environ.get("OPENAI_API_KEY") or os.environ.get("GENERALCOMPUTE_API_KEY")
            if not key and os.path.exists("/run/secrets/generalcompute-api-key"):
                try:
                    with open("/run/secrets/generalcompute-api-key", "r") as f:
                        key = f.read().strip()
                except Exception:
                    pass
            return key or ""

        API_KEY = get_api_key()

        class ProxyHandler(BaseHTTPRequestHandler):
            def do_POST(self):
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length)

                if self.path.endswith("/chat/completions"):
                    try:
                        payload = json.loads(body.decode("utf-8"))
                    except Exception:
                        payload = {}

                    payload["model"] = PRIMARY_MODEL
                    success, code, resp_body, resp_headers = self._forward_request(payload)

                    if not success or code >= 400:
                        sys.stderr.write(f"[gc-proxy] Primary model {PRIMARY_MODEL} returned {code}, falling back to {FALLBACK_MODEL}...\n")
                        sys.stderr.flush()
                        payload["model"] = FALLBACK_MODEL
                        success, code, resp_body, resp_headers = self._forward_request(payload)

                    self.send_response(code)
                    for k, v in resp_headers.items():
                        if k.lower() not in ("content-length", "transfer-encoding", "content-encoding"):
                            self.send_header(k, v)
                    self.send_header("Content-Length", str(len(resp_body)))
                    self.end_headers()
                    self.wfile.write(resp_body)
                else:
                    self._passthrough("POST", body)

            def do_GET(self):
                self._passthrough("GET", None)

            def _forward_request(self, payload):
                target_url = f"{UPSTREAM_BASE}/chat/completions"
                data = json.dumps(payload).encode("utf-8")
                headers = {
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {API_KEY}",
                }
                req = urllib.request.Request(target_url, data=data, headers=headers, method="POST")
                try:
                    with urllib.request.urlopen(req, timeout=60) as resp:
                        return True, resp.status, resp.read(), dict(resp.headers)
                except urllib.error.HTTPError as e:
                    return False, e.code, e.read(), dict(e.headers)
                except Exception as e:
                    err_json = json.dumps({"error": str(e)}).encode("utf-8")
                    return False, 502, err_json, {"Content-Type": "application/json"}

            def _passthrough(self, method, body):
                subpath = self.path
                if subpath.startswith("/v1"):
                    subpath = subpath[3:]
                target_url = f"{UPSTREAM_BASE}{subpath}"
                headers = {
                    "Authorization": f"Bearer {API_KEY}",
                }
                if body:
                    headers["Content-Type"] = self.headers.get("Content-Type", "application/json")

                req = urllib.request.Request(target_url, data=body, headers=headers, method=method)
                try:
                    with urllib.request.urlopen(req, timeout=30) as resp:
                        resp_data = resp.read()
                        self.send_response(resp.status)
                        for k, v in resp.headers.items():
                            if k.lower() not in ("content-length", "transfer-encoding", "content-encoding"):
                                self.send_header(k, v)
                        self.send_header("Content-Length", str(len(resp_data)))
                        self.end_headers()
                        self.wfile.write(resp_data)
                except urllib.error.HTTPError as e:
                    err_data = e.read()
                    self.send_response(e.code)
                    for k, v in e.headers.items():
                        if k.lower() not in ("content-length", "transfer-encoding", "content-encoding"):
                            self.send_header(k, v)
                    self.send_header("Content-Length", str(len(err_data)))
                    self.end_headers()
                    self.wfile.write(err_data)
                except Exception as e:
                    err_json = json.dumps({"error": str(e)}).encode("utf-8")
                    self.send_response(502)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(err_json)))
                    self.end_headers()
                    self.wfile.write(err_json)

            def log_message(self, format, *args):
                pass

        if __name__ == "__main__":
            server = HTTPServer(("127.0.0.1", PORT), ProxyHandler)
            try:
                server.serve_forever()
            except KeyboardInterrupt:
                pass
      '';
      # Voyage AI speaks a *partly* OpenAI-compatible dialect, and supermemory's
      # `openai` embedding provider sends `"encoding_format":"float"` which
      # Voyage rejects with a 400 (it only accepts "base64"). This proxy
      # translates the two dialects; see the file header for the full list.
      voyageProxyScript = pkgs.writeScript "voyage-embeddings-proxy.py" (
        builtins.readFile ./voyage-embeddings-proxy.py
      );
    in
    {
      environment.systemPackages = [
        supermemory-server
      ];

      sops.templates."supermemory.env" = {
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
        path = "/run/secrets/supermemory.env";
        content = ''
          PORT=6767
          SUPERMEMORY_DATA_DIR=/home/parazeeknova/.supermemory
          # Embeddings run on Voyage AI through the translating proxy below.
          # voyage-4-large accepts 256/512/1024/2048, but supermemory refuses
          # anything above the pgvector HNSW limit of 2000, so 1024 is the
          # largest usable width. Dimensions are LOCKED once data exists:
          # changing provider/model/dimensions requires wiping the data dir,
          # because the server refuses to boot on a mismatch.
          SUPERMEMORY_EMBEDDING_PROVIDER=openai
          SUPERMEMORY_EMBEDDING_MODEL=voyage-4-large
          SUPERMEMORY_EMBEDDING_DIMENSIONS=1024
          SUPERMEMORY_EMBEDDING_BASE_URL=http://127.0.0.1:6797/v1
          SUPERMEMORY_EMBEDDING_API_KEY=${config.sops.placeholder.voyage-api-key}
          VOYAGE_API_KEY=${config.sops.placeholder.voyage-api-key}
          VOYAGE_OUTPUT_DIMENSION=1024
          VOYAGE_MAX_RPM=0
          VOYAGE_MAX_TPM=0
          OPENAI_BASE_URL=http://127.0.0.1:6768/v1
          OPENAI_API_KEY=${config.sops.placeholder.generalcompute-api-key}
          OPENAI_MODEL=deepseek-v3.2
          GC_PROXY_PORT=6768
          GC_PRIMARY_MODEL=deepseek-v3.2
          GC_FALLBACK_MODEL=minimax-m2.7
        '';
      };

      home-manager.users.parazeeknova =
        { config, ... }:
        {
          home.sessionVariables = {
            SUPERMEMORY_API_URL = "http://localhost:6767";
          };

          systemd.user.services.supermemory-gc-proxy = {
            Unit = {
              Description = "General Compute Failover Proxy for Supermemory (deepseek-v3.2 -> minimax-m2.7)";
              After = [ "network.target" ];
            };

            Service = {
              Type = "simple";
              ExecStart = "${gcProxyScript}";
              Restart = "always";
              RestartSec = 3;
              EnvironmentFile = [
                "-/run/secrets/supermemory.env"
              ];
              Environment = [
                "GC_PROXY_PORT=6768"
                "GC_PRIMARY_MODEL=deepseek-v3.2"
                "GC_FALLBACK_MODEL=minimax-m2.7"
              ];
            };

            Install = {
              WantedBy = [ "default.target" ];
            };
          };

          systemd.user.services.voyage-embeddings-proxy = {
            Unit = {
              Description = "Voyage AI <-> OpenAI embeddings translation proxy for Supermemory (Port 6797)";
              After = [ "network.target" ];
            };

            Service = {
              Type = "simple";
              ExecStart = "${pkgs.python3}/bin/python3 ${voyageProxyScript}";
              Restart = "always";
              RestartSec = 3;
              EnvironmentFile = [
                "-/run/secrets/supermemory.env"
              ];
              Environment = [
                "VOYAGE_PROXY_PORT=6797"
                # supermemory omits a dimensions field, so without this Voyage
                # would silently answer with its 1024 default. Keep in sync
                # with SUPERMEMORY_EMBEDDING_DIMENSIONS below.
                "VOYAGE_OUTPUT_DIMENSION=1024"
                # Pacing disabled: this key's limits are well above Voyage's
                # unpaid tier. The proxy still coalesces concurrent requests and
                # retries 429/5xx with backoff. For an unpaid key, set
                # VOYAGE_MAX_RPM=3 and VOYAGE_MAX_TPM=10000 here.
                "VOYAGE_MAX_RPM=0"
                "VOYAGE_MAX_TPM=0"
              ];
            };

            Install = {
              WantedBy = [ "default.target" ];
            };
          };

          systemd.user.services.supermemory-server = {
            Unit = {
              Description = "Supermemory Local Memory Server (Port 6767)";
              After = [
                "network.target"
                "supermemory-gc-proxy.service"
                "voyage-embeddings-proxy.service"
              ];
              Wants = [
                "supermemory-gc-proxy.service"
                "voyage-embeddings-proxy.service"
              ];
            };

            Service = {
              Type = "simple";
              ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/.supermemory";
              ExecStart = "${supermemory-server}/bin/supermemory-server";
              Restart = "always";
              RestartSec = 5;
              WorkingDirectory = "%h";
              EnvironmentFile = [
                "-/run/secrets/supermemory.env"
              ];
              Environment = [
                "PORT=6767"
                "SUPERMEMORY_DATA_DIR=%h/.supermemory"
                "SUPERMEMORY_EMBEDDING_PROVIDER=openai"
                "SUPERMEMORY_EMBEDDING_MODEL=voyage-4-large"
                "SUPERMEMORY_EMBEDDING_DIMENSIONS=1024"
                "SUPERMEMORY_EMBEDDING_BASE_URL=http://127.0.0.1:6797/v1"
                "OPENAI_BASE_URL=http://127.0.0.1:6768/v1"
                "OPENAI_MODEL=deepseek-v3.2"
              ];
            };

            Install = {
              WantedBy = [ "default.target" ];
            };
          };
        };
    };
}
