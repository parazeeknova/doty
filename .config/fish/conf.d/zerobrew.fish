# >>> zerobrew >>>
# zerobrew
set -gx ZEROBREW_DIR "/home/paper/.zerobrew"
set -gx ZEROBREW_BIN "/home/paper/.zerobrew/bin"
set -gx ZEROBREW_ROOT "/home/paper/.local/share/zerobrew"
set -gx ZEROBREW_PREFIX "/home/paper/.local/share/zerobrew/prefix"
if set -q PKG_CONFIG_PATH
    set -gx PKG_CONFIG_PATH "$ZEROBREW_PREFIX/lib/pkgconfig" $PKG_CONFIG_PATH
else
    set -gx PKG_CONFIG_PATH "$ZEROBREW_PREFIX/lib/pkgconfig"
end

# SSL/TLS certificates (only if ca-certificates is installed)
if not set -q CURL_CA_BUNDLE; or not set -q SSL_CERT_FILE
    if test -f "$ZEROBREW_PREFIX/opt/ca-certificates/share/ca-certificates/cacert.pem"
        set -q CURL_CA_BUNDLE; or set -gx CURL_CA_BUNDLE "$ZEROBREW_PREFIX/opt/ca-certificates/share/ca-certificates/cacert.pem"
        set -q SSL_CERT_FILE; or set -gx SSL_CERT_FILE "$ZEROBREW_PREFIX/opt/ca-certificates/share/ca-certificates/cacert.pem"
    else if test -f "$ZEROBREW_PREFIX/etc/ca-certificates/cacert.pem"
        set -q CURL_CA_BUNDLE; or set -gx CURL_CA_BUNDLE "$ZEROBREW_PREFIX/etc/ca-certificates/cacert.pem"
        set -q SSL_CERT_FILE; or set -gx SSL_CERT_FILE "$ZEROBREW_PREFIX/etc/ca-certificates/cacert.pem"
    else if test -f "$ZEROBREW_PREFIX/etc/openssl/cert.pem"
        set -q CURL_CA_BUNDLE; or set -gx CURL_CA_BUNDLE "$ZEROBREW_PREFIX/etc/openssl/cert.pem"
        set -q SSL_CERT_FILE; or set -gx SSL_CERT_FILE "$ZEROBREW_PREFIX/etc/openssl/cert.pem"
    else if test -f "$ZEROBREW_PREFIX/share/ca-certificates/cacert.pem"
        set -q CURL_CA_BUNDLE; or set -gx CURL_CA_BUNDLE "$ZEROBREW_PREFIX/share/ca-certificates/cacert.pem"
        set -q SSL_CERT_FILE; or set -gx SSL_CERT_FILE "$ZEROBREW_PREFIX/share/ca-certificates/cacert.pem"
    end
end

if not set -q SSL_CERT_DIR
    if test -d "$ZEROBREW_PREFIX/etc/ca-certificates"
        set -gx SSL_CERT_DIR "$ZEROBREW_PREFIX/etc/ca-certificates"
    else if test -d "$ZEROBREW_PREFIX/etc/openssl/certs"
        set -gx SSL_CERT_DIR "$ZEROBREW_PREFIX/etc/openssl/certs"
    else if test -d "$ZEROBREW_PREFIX/share/ca-certificates"
        set -gx SSL_CERT_DIR "$ZEROBREW_PREFIX/share/ca-certificates"
    end
end

if not contains -- "$ZEROBREW_BIN" $PATH
    set -gx PATH "$ZEROBREW_BIN" $PATH
end
if not contains -- "$ZEROBREW_PREFIX/bin" $PATH
    set -gx PATH "$ZEROBREW_PREFIX/bin" $PATH
end

# <<< zerobrew <<<
