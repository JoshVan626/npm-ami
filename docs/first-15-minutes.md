# First 15 Minutes

A time-boxed flow to go from AMI launch to your first proxy host. For the full walkthrough, see [Quickstart](quickstart.md).

---

## 0–2 min: Launch the instance

1. Launch an instance from the NPM for AWS AMI (AWS Console or IaC).
2. Configure security group: allow `22`, `80`, `443` from your IP; allow `81` from your IP (or use SSH tunnel).
3. Launch and note the instance public IP.

**IaC quick start (Terraform):**

```bash
cd deploy/terraform
terraform init
terraform apply -var-file=examples/minimal.tfvars
```

---

## 2–5 min: Wait for first boot

The instance runs preflight, init, and post-init. This usually takes **2–5 minutes**.

**Check progress (optional):** Use EC2 Instance Connect or SSH to inspect:

```bash
ssh ubuntu@<instance-ip>
# Check MOTD for "Initialization Status"
sudo npm-helper status
```

Expected: `Init: complete` when ready.

---

## 5–7 min: Get credentials and access Admin UI

1. SSH in:

   ```bash
   ssh -i /path/to/key.pem ubuntu@<instance-ip>
   ```

2. Retrieve credentials:

   ```bash
   sudo npm-helper show-creds
   ```

3. Access the Admin UI:
   - **If port 81 is allowed from your IP:** open `http://<instance-ip>:81`
   - **Otherwise, use SSH tunnel:**
     ```bash
     ssh -i /path/to/key.pem -L 8181:localhost:81 ubuntu@<instance-ip>
     ```
     Then open `http://localhost:8181`

4. Log in with the username and password from step 2.

---

## 7–15 min: Create your first proxy host

1. In NPM, go to **Hosts → Proxy Hosts → Add Proxy Host**.
2. Set:
   - **Domain Names:** `app.example.com` (or your domain)
   - **Scheme:** `http`
   - **Forward Hostname / IP:** internal app address (e.g. `10.0.1.23` or `localhost`)
   - **Forward Port:** e.g. `3000`
3. Save.
4. (Optional) Enable SSL and Let's Encrypt once DNS points to the instance.

---

## Quick validation

```bash
sudo npm-helper status
sudo npm-helper cert-check
```

---

## Next steps

- [Backup & Restore](backup-restore.md) – configure backups
- [Security](security.md) – understand hardening and admin access
- [Upgrades](upgrades.md) – upgrade and rollback guidance
