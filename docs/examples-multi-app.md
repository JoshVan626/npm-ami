# Example: Hosting Multiple Apps Behind NPM

A common use case is to run multiple applications behind a single NPM instance
on EC2.

---

## Scenario

You have:

- One NPM Premium AMI instance
- Two backend apps:

  - `app1` on another EC2 instance at `10.0.1.10:3000`
  - `app2` on another EC2 instance at `10.0.1.11:4000`

You want:

- `https://app1.example.com` → `10.0.1.10:3000`
- `https://app2.example.com` → `10.0.1.11:4000`

---

## Steps

1. Point DNS (`A` records) for:

   - `app1.example.com` → NPM instance public IP or load balancer
   - `app2.example.com` → NPM instance public IP or load balancer

2. In NPM admin UI:

   - **Add Proxy Host** for `app1.example.com`:
     - Domain Names: `app1.example.com`
     - Scheme: `http`
     - Forward Hostname / IP: `10.0.1.10`
     - Forward Port: `3000`
     - Enable SSL (Let’s Encrypt) once DNS is working.

   - **Add Proxy Host** for `app2.example.com`:
     - Domain Names: `app2.example.com`
     - Scheme: `http`
     - Forward Hostname / IP: `10.0.1.11`
     - Forward Port: `4000`
     - Enable SSL (Let’s Encrypt) once DNS is working.

3. (Optional) Put the NPM instance behind an Application Load Balancer (ALB)
   that terminates TLS and forwards to the NPM instance. In that case, you can
   run NPM in HTTP-only mode internally and let ALB handle TLS.

---

## Tips

- Consider using private subnets and security groups so only the NPM instance
  can reach your backend apps.
- Use separate NPM access lists if some apps should be restricted.
- Use backups to protect NPM configuration and TLS certificates.
