# DNS and certificate patterns

This document gives turnkey patterns for pointing DNS at your NPM instance and for certificate management with Nginx Proxy Manager.

---

## DNS patterns

### AWS Route 53

Point your NPM hostname (e.g. `npm.example.com` or `proxy.example.com`) at the instance:

- **A record:** Create an A record that points to the instance’s **Elastic IP** (recommended) or its public IP. If you use an EIP, the record stays valid across instance replacements (e.g. blue/green upgrades).
- **CNAME:** Alternatively, create a CNAME to the instance’s public DNS name (e.g. `ec2-12-34-56-78.compute-1.amazonaws.com`). This is simpler but the hostname changes if you replace the instance.

Example (manual in Route 53 console):

- **Name:** `npm` (or your subdomain)
- **Type:** A
- **Value:** your Elastic IP (e.g. `52.1.2.3`)
- **TTL:** 300 (or your preference)

If you use Terraform, you can add a Route 53 record that points to the instance’s EIP or public IP; see the optional snippet below.

### CloudFlare

- Create an **A** or **CNAME** record for your NPM hostname.
- **Value:** Your instance’s Elastic IP or public IP (for A), or the instance public DNS (for CNAME).
- **Proxy status:** You can use “Proxied” (orange cloud) for DDoS and caching, or “DNS only” (grey) so traffic goes directly to your instance. For a reverse proxy like NPM, “DNS only” is common so NPM sees the real client IP and handles TLS termination; “Proxied” can work if you rely on CloudFlare’s headers for client IP.

---

## Certificates (Let’s Encrypt)

Nginx Proxy Manager manages TLS certificates via its **admin UI**:

1. Log in to NPM (port 81).
2. Add **Hosts** → **SSL Certificates** and request a certificate (e.g. Let’s Encrypt).
3. Attach the certificate to your **Proxy Hosts**.

NPM uses ACME (e.g. Let’s Encrypt) and stores certificates under `/opt/npm/letsencrypt` on the AMI. No extra “turnkey template” is required beyond configuring NPM’s built-in cert flow.

This AMI adds **operational visibility** around certs:

- **`npm-helper cert-check`** (or **`northstar`** equivalent): Runs the certificate expiry check. Configure threshold in `/etc/npm-cert-check.conf` (e.g. `threshold_days`).
- **CloudWatch:** When the CloudWatch baseline is enabled, cert expiry warnings are shipped to CloudWatch Logs and can trigger alarms (see [Monitoring and metrics](./monitoring-and-metrics.md)).

Run a one-off check:

```bash
sudo npm-helper cert-check
```

---

## Optional: Route 53 A record with Terraform

If you deploy the instance with the Terraform in `deploy/terraform/`, you can add a Route 53 A record that points to the instance’s EIP. Example (add to your Terraform or a separate module):

```hcl
# Optional: point a DNS name at the NPM instance (EIP)
variable "npm_zone_id" {
  description = "Route 53 hosted zone ID for the domain"
  type        = string
  default     = ""
}
variable "npm_fqdn" {
  description = "FQDN for NPM (e.g. npm.example.com)"
  type        = string
  default     = ""
}

resource "aws_route53_record" "npm" {
  count   = var.npm_zone_id != "" && var.npm_fqdn != "" ? 1 : 0
  zone_id = var.npm_zone_id
  name    = var.npm_fqdn
  type    = "A"
  ttl     = 300
  records = [aws_eip.npm[0].public_ip]  # adjust to your EIP resource name
}
```

Adjust `aws_eip.npm[0].public_ip` to match your EIP resource. If your template does not create an EIP, use the instance’s `public_ip` or an existing EIP data source.
