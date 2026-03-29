# cert-manager (Flux)

Jetstack Helm chart for **Certificates** / ACME.

**ClusterIssuer** for production Let’s Encrypt lives in **`gitops/infrastructure/cert-manager-issuers/`** (HTTP-01, **traefik** class). Ingresses: **`cert-manager.io/cluster-issuer: letsencrypt-prod`**.

For experiments, a **staging** issuer is the same shape with Let’s Encrypt staging URL — see [cert-manager docs](https://cert-manager.io/docs/configuration/acme/).
