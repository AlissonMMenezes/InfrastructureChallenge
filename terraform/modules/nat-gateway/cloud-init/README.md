# NAT gateway cloud-init (Terraform only)

- **Source of truth:** [`nat-gateway.yaml.tpl`](nat-gateway.yaml.tpl) is rendered with `templatefile()` in `nat-gateway/main.tf` (`locals.user_data`) and passed to **`hcloud_server.user_data`** via the `compute` module. All NAT packages, sysctl, iptables rules, scripts, systemd units, and `runcmd` live here.
- **Hetzner limitation:** `user_data` runs **only when the server is created or rebuilt**. Changing this template in Git **does not** change an existing jump until you **replace** or **rebuild** that server.
- **Apply updated cloud-init to an existing jump:**

  ```bash
  terraform apply -replace='module.kubernetes.module.nat_gateway.module.compute.hcloud_server.this["<jump-server-name>"]'
  ```

  Use `terraform state list | grep jump` to confirm the address (example name: `dev-test-jump-1`).

**Verify after first boot**

- `test -f /var/lib/cloud/hetzner-nat-cloud-init-stamp && echo ok`
- `systemctl status hetzner-nat-gateway.service`
- `sudo iptables -t nat -S POSTROUTING | grep MASQUERADE`
