#!/bin/sh
# Configures OpenBao auth/kubernetes for in-cluster JWTs (External Secrets PushSecret + ExternalSecret).
# Runs as the OpenBao server ServiceAccount so token_reviewer_jwt satisfies TokenReview (chart authDelegator CRB).
set -eu

BAO_ADDR="${BAO_ADDR:-http://openbao.openbao-system.svc.cluster.local:8200}"
TOKEN_FILE="${TOKEN_FILE:-/bootstrap/root-token}"

if [ ! -s "$TOKEN_FILE" ]; then
  echo "SKIP: no root token at $TOKEN_FILE. Create Secret openbao-bootstrap (key root-token) in openbao-system, then delete Job openbao-kubernetes-auth-bootstrap so Flux recreates it."
  exit 0
fi

BAO_TOKEN="$(tr -d '\n\r' <"$TOKEN_FILE")"
export BAO_ADDR BAO_TOKEN

echo "Waiting for OpenBao at $BAO_ADDR ..."
i=0
while ! bao status >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -gt 120 ]; then
    echo "Timeout waiting for OpenBao"
    exit 1
  fi
  sleep 3
done

if ! bao status 2>/dev/null | grep -qi 'Initialized.*true'; then
  echo "SKIP: OpenBao not initialized yet. Run bao operator init, then: kubectl delete job -n openbao-system openbao-kubernetes-auth-bootstrap"
  exit 0
fi

if ! bao status 2>/dev/null | grep -qi 'Sealed.*false'; then
  echo "SKIP: OpenBao is sealed. Unseal, then: kubectl delete job -n openbao-system openbao-kubernetes-auth-bootstrap"
  exit 0
fi

# KV v2 at mount "secret" (matches ClusterSecretStore path: secret)
bao secrets enable -path=secret kv-v2 2>/dev/null || true

if ! bao auth list 2>/dev/null | grep -q '^kubernetes/'; then
  bao auth enable kubernetes
fi

bao write auth/kubernetes/config \
  kubernetes_host="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token \
  disable_local_ca_jwt=false

bao policy write external-secrets-openbao "@/scripts/external-secrets-openbao.hcl"

bao write auth/kubernetes/role/external-secrets \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=external-secrets-openbao \
  ttl=1h \
  max_ttl=24h

echo "OpenBao Kubernetes auth ready: mount kubernetes, role external-secrets, policy external-secrets-openbao."
