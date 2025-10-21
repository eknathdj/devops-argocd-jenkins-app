Security and secret handling

This repository previously contained hard-coded base64-encoded secrets in `k8s/product-service/01-secrets.yaml`.

Actions required immediately:

- Rotate all exposed credentials (DB users/passwords, API keys, tokens). Treat them as compromised.
- Do not use the old credentials. Update your secret manager with new credentials.
- Purge the secrets from git history using `git filter-repo` or BFG:
  - Example (using git-filter-repo):
    1. Install git-filter-repo.
    2. git clone --mirror <repo_url> repo.git
    3. cd repo.git
    4. git filter-repo --invert-paths --paths k8s/product-service/01-secrets.yaml
    5. git push --force
  - Or use BFG: https://rtyley.github.io/bfg-repo-cleaner/

Recommended long-term fixes:

- Use an external secrets manager: SealedSecrets, External Secrets Operator, HashiCorp Vault, or cloud provider secret manager.
- Store only templates or references in the repo (no base64 values).
- Add secret scanning (gitleaks) to CI and pre-commit hooks to prevent accidental commits.
- Enable branch protection and require scans to pass on pull requests.

Example: convert `01-secrets.yaml` to a template or use ExternalSecret CRD to reference secrets at runtime.

If you need assistance performing history rewrite or rotating keys, contact your security/ops team immediately.
