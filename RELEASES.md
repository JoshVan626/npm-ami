# Release Notes (AMI)

Use this file to track AMI releases that correspond to AWS Marketplace versions.

## Releases

## Compatibility Matrix

| AMI Release | Pinned NPM Image | Supported In-Place Path | Rollback Command |
|---|---|---|---|
| v1.0.0-rc1 | `jc21/nginx-proxy-manager:2.13.5` | `sudo npm-helper upgrade --dry-run` then `sudo npm-helper upgrade` | `sudo npm-helper rollback` |

Notes:
- Preferred production upgrade remains AMI replacement + restore.
- In-place updates must remain backup-first.
- Update this matrix for every release entry below.

### Version: v1.0.0-rc1
**Date:** 2026-02-10 (UTC)  
**Commit:** TBD (set to `git rev-parse HEAD` at release time)  

**Highlights:**
- Enforce IMDSv2 and enable encrypted root EBS volumes in Terraform and CloudFormation templates.
- Tighten Docker privileges by removing default `docker` group membership for the `ubuntu` user (sudo-only Docker usage).
- Make CloudWatch Agent install deterministic and optional by using the `amazon-cloudwatch-agent` apt package only.
- Add non-interactive support to the AMI cleanup script via `--yes` and `NORTHSTAR_NONINTERACTIVE=1`.
- Write a build manifest to `/opt/northstar/build-manifest.txt` with OS, kernel, Docker, NPM image, and dpkg snapshot metadata.
- Clarify the two-gate admin port 81 access model (security group + instance firewall/UFW) in the documentation.

**Notes:**
- Recommended for new Marketplace listings and as the first \"golden\" image candidate.
- Prefer this version over earlier internal builds; older AMIs may not enforce IMDSv2 or root volume encryption.

---

## Template

### Version: <ami-version-or-marketplace-version>
**Date:** YYYY-MM-DD  
**AMI ID(s):**  
- us-east-1: ami-xxxxxxxxxxxxxxxxx  
- us-west-2: ami-xxxxxxxxxxxxxxxxx  
**Pinned NPM Image:** jc21/nginx-proxy-manager:<tag>  
**Supported In-Place Upgrade Path:** `sudo npm-helper upgrade --dry-run` -> `sudo npm-helper upgrade`  
**Rollback Path:** `sudo npm-helper rollback`  

**Highlights:**
- <short change summary>
- <security updates / dependency changes>
- <bug fixes>

**Notes:**
- <known limitations or upgrade guidance>

---

## Maintenance guidance

- Keep entries short and customer-focused.
- Include security-relevant changes (OS packages, Docker, NPM image updates).
- Link to any internal build/test evidence as needed (not publicly shared).
- If a release supersedes a prior AMI, note the preferred upgrade path.
