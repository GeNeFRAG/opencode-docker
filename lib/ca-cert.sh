# ─── lib/ca-cert.sh ─────────────────────────────────────────────────────────
# Install corporate CA certificate if mounted at /certs/ca-bundle.pem.
# Sets NODE_EXTRA_CA_CERTS and REQUESTS_CA_BUNDLE for Node/Python consumers.

CA_CERT="/certs/ca-bundle.pem"
if [ -f "${CA_CERT}" ] && [ -s "${CA_CERT}" ]; then
    echo "→ Installing corporate CA certificate..."
    cp "${CA_CERT}" /usr/local/share/ca-certificates/custom-ca.crt 2>/dev/null || true
    update-ca-certificates 2>/dev/null || true
    export NODE_EXTRA_CA_CERTS="${CA_CERT}"
    export REQUESTS_CA_BUNDLE="${CA_CERT}"
    echo "  ✓ CA certificate installed"
fi
