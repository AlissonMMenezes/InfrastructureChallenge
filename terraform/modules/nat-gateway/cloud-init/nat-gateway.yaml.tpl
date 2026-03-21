#cloud-config
# SNAT for private clients: MASQUERADE traffic sourced from nat_source_cidr via WAN (-o default route).
# Rendered by Terraform (templatefile) and passed as hcloud_server.user_data only — no Ansible duplication.
# Hetzner runs this at server create/rebuild; see cloud-init/README.md.
package_update: true
packages:
  - iptables
  - iptables-persistent
write_files:
  - path: /var/lib/cloud/hetzner-nat-cloud-init-stamp
    permissions: "0644"
    content: |
      NAT gateway cloud-init module applied (Terraform nat-gateway). Scripts: /usr/local/sbin/hetzner-nat-gateway.sh
  - path: /etc/sysctl.d/99-nat-gateway.conf
    permissions: "0644"
    content: |
      net.ipv4.ip_forward=1
      net.ipv4.conf.all.rp_filter=0
      net.ipv4.conf.default.rp_filter=0
  - path: /usr/local/sbin/hetzner-nat-gateway.sh
    permissions: "0755"
    content: |
      #!/usr/bin/env bash
      set -euo pipefail

      # Detect the public interface dynamically
      WAN_IF=$(ip route | awk '/^default/ {print $5; exit}')

      # Enable IP forwarding so the server can route packets
      sysctl -w net.ipv4.ip_forward=1
      sed -i 's/^#\?net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf

      # Replace source IP of packets from the private subnet with the NAT gateway's public IP
      iptables -t nat -C POSTROUTING -s ${nat_source_cidr} -o "$WAN_IF" -j MASQUERADE 2>/dev/null || \
      iptables -t nat -A POSTROUTING -s ${nat_source_cidr} -o "$WAN_IF" -j MASQUERADE

      # Allow forwarding outbound packets from private subnet
      iptables -C FORWARD -s ${nat_source_cidr} -o "$WAN_IF" -j ACCEPT 2>/dev/null || \
      iptables -A FORWARD -s ${nat_source_cidr} -o "$WAN_IF" -j ACCEPT

      # Allow return traffic for established connections
      iptables -C FORWARD -d ${nat_source_cidr} -m conntrack --ctstate ESTABLISHED,RELATED -i "$WAN_IF" -j ACCEPT 2>/dev/null || \
      iptables -A FORWARD -d ${nat_source_cidr} -m conntrack --ctstate ESTABLISHED,RELATED -i "$WAN_IF" -j ACCEPT
  - path: /etc/systemd/system/hetzner-nat-gateway.service
    permissions: "0644"
    owner: root:root
    content: |
      [Unit]
      Description=Configure NAT for private subnet egress
      After=network-online.target
      Wants=network-online.target

      [Service]
      Type=oneshot
      ExecStart=/usr/local/sbin/hetzner-nat-gateway.sh
      RemainAfterExit=yes

      [Install]
      WantedBy=multi-user.target
runcmd:
  - systemctl daemon-reload
  - systemctl enable hetzner-nat-gateway.service
  - systemctl start hetzner-nat-gateway.service
