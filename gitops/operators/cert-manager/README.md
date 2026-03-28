# cert-manager (Flux)

Installs [cert-manager](https://cert-manager.io/) from the Jetstack Helm repo for **ACME / Let’s Encrypt** (and other issuers).

## Next step: ClusterIssuer

The Helm chart does not create a Let’s Encrypt account for you. Apply a **`ClusterIssuer`** (or namespaced **`Issuer`**) with your email and solver (HTTP-01, DNS-01, etc.). Example **staging** issuer:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    email: you@example.com
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
      - http01:
          ingress:
            class: traefik
```

Use `https://acme-v02.api.letsencrypt.org/directory` for production after testing.

Reference issuers in **`Certificate`** resources or **`Ingress`** annotations (`cert-manager.io/cluster-issuer`).
