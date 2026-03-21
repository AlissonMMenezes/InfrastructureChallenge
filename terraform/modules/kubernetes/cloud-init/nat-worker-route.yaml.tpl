#cloud-config
# Egress model (Hetzner Cloud L3 network):
# - Persistent default route via systemd-networkd (survives DHCP renewals); gateway = platform IP.
# - Internet (0.0.0.0/0) reaches NAT at nat_gateway_private_ip via Terraform hcloud_network_route.
# - Two .network files cover Hetzner NIC names (enp7s0 vs ens10); only the existing iface matches.
write_files:
  - path: /etc/hcloud-egress.env
    permissions: "0644"
    content: |
      # Written by cloud-init (Terraform).
      HETZNER_PLATFORM_GATEWAY_IP=${private_network_gateway_ip}
      NAT_GATEWAY_PRIVATE_IP=${nat_gateway_private_ip}
  # Replies to ping/curl via NAT are asymmetric; strict rp_filter drops them on the private NIC.
  - path: /etc/sysctl.d/99-nat-client-rpfilter.conf
    permissions: "0644"
    content: |
      net.ipv4.conf.all.rp_filter=0
      net.ipv4.conf.default.rp_filter=0
  # Global fallback; per-link DNS on the private NIC (below) is what actually fixes Hetzner DHCP (often empty DNS).
  - path: /etc/systemd/resolved.conf.d/99-nat-egress-dns.conf
    permissions: "0644"
    content: |
      [Resolve]
      DNS=8.8.8.8 1.1.1.1
      FallbackDNS=
      DNSStubListener=yes
  # Route + DNS on the private NIC: ignore DHCP/RA DNS (usually missing or useless) and use public resolvers.
  - path: /etc/systemd/network/70-hetzner-private-default-enp7s0.network
    permissions: "0644"
    content: |
      [Match]
      Name=enp7s0

      [Network]
      DNS=8.8.8.8
      DNS=1.1.1.1
      Domains=~.

      [DHCPv4]
      UseDNS=no
      UseDomains=no

      [IPv6AcceptRA]
      UseDNS=no

      [Route]
      Destination=0.0.0.0/0
      Gateway=${private_network_gateway_ip}
      GatewayOnLink=yes
      Metric=50
  - path: /etc/systemd/network/70-hetzner-private-default-ens10.network
    permissions: "0644"
    content: |
      [Match]
      Name=ens10

      [Network]
      DNS=8.8.8.8
      DNS=1.1.1.1
      Domains=~.

      [DHCPv4]
      UseDNS=no
      UseDomains=no

      [IPv6AcceptRA]
      UseDNS=no

      [Route]
      Destination=0.0.0.0/0
      Gateway=${private_network_gateway_ip}
      GatewayOnLink=yes
      Metric=50
  # Additional Hetzner private NIC names (see Hetzner “Networks” docs / server types).
  - path: /etc/systemd/network/70-hetzner-private-default-enp8s0.network
    permissions: "0644"
    content: |
      [Match]
      Name=enp8s0

      [Network]
      DNS=8.8.8.8
      DNS=1.1.1.1
      Domains=~.

      [DHCPv4]
      UseDNS=no
      UseDomains=no

      [IPv6AcceptRA]
      UseDNS=no

      [Route]
      Destination=0.0.0.0/0
      Gateway=${private_network_gateway_ip}
      GatewayOnLink=yes
      Metric=50
  - path: /usr/local/sbin/worker-set-default-via-nat.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      set -euo pipefail
      GW="${private_network_gateway_ip}"
      NAT="${nat_gateway_private_ip}"
      for _ in $(seq 1 30); do
        IFACE=$(ip -4 route get "$$GW" 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($$i=="dev"){print $$(i+1);exit}}')
        if [ -n "$${IFACE:-}" ]; then
          ip -4 route del default 2>/dev/null || true
          ip -4 route replace default via "$$GW" dev "$$IFACE" metric 50
          logger -t worker-nat-route "default via $$GW dev $$IFACE; NAT $$NAT"
          exit 0
        fi
        sleep 1
      done
      echo "worker-nat-route: no path to platform gateway $$GW (NAT $$NAT)" >&2
      exit 1
  - path: /etc/systemd/system/worker-nat-default-route.service
    permissions: "0644"
    content: |
      [Unit]
      Description=Ensure default route via Hetzner platform GW (fallback if needed); NAT ${nat_gateway_private_ip}
      After=systemd-networkd.service network-online.target
      Wants=network-online.target

      [Service]
      Type=oneshot
      ExecStart=/usr/local/sbin/worker-set-default-via-nat.sh
      RemainAfterExit=yes

      [Install]
      WantedBy=multi-user.target
runcmd:
  - sysctl --system
  - systemctl daemon-reload
  - systemctl enable systemd-resolved
  # Apply .network (routes + DNS); then resolved picks up per-link DNS from networkd
  - systemctl restart systemd-networkd
  - systemctl restart systemd-resolved
  - resolvectl flush-caches || true
  - systemctl enable worker-nat-default-route.service
  - systemctl start worker-nat-default-route.service
