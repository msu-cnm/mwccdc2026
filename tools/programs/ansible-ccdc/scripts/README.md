# Scripts

Operator helper script used during competition.

---

## Scripts

- `bootstrap.sh`  
  Prepares the control node (virtual environment, Ansible, required collections).

---

## Notes

- Scripts must not modify repository contents
- Scripts must not print secrets or decrypted vault values
- All system changes are performed via Ansible playbooks
