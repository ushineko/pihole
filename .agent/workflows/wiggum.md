---
description: Iteratively run, capture logs, and debug the Pi-hole container until a success condition is met.
---

1.  **Preparation**:
    *   **Identify Goal**: What is the **Success Condition**? (e.g., "Web interface accessible", "DNS resolution works", "Error X is gone from logs").
    *   **Ensure Baseline**:
        *   Run `make setup` to ensure all persistent configurations (reverse DNS, admin password) are initialized on the host.
    *   **Ensure Observability**:
        *   The main source of observation is `make logs`.

2.  **Clean Slate**:
    *   **Kill Existing Instances**: `make stop`.
    *   **Clear Statistics**: `make flush`.

3.  **Execution Loop**:
    *   **Run**: `make start`.
    *   **Capture**: `make logs`.
    *   **Analyze**:
        *   Did the **Success Condition** occur?
        *   Check `make status`.
    *   **Decision**:
        *   **Success**: Proceed to **Finalization**.
        *   **Failure**:
            *   Analyze logs.
            *   **Adjust**: Apply fixes to `docker-compose.yml`, `etc-dnsmasq.d/`, or `scripts/setup.sh`.
            *   > [!IMPORTANT]
            *   > **Persistence Rule**: Changes made directly inside the running container (e.g., via `docker exec`) are **ephemeral** and will be lost on the next loop.
            *   > All configuration changes must be driven by:
            *   > 1.  `docker-compose.yml` (preferred for v6 `FTLCONF_` settings).
            *   > 2.  Mounted configurations in `etc-dnsmasq.d/` or `etc-pihole/`.
            *   > 3.  The `scripts/setup.sh` script (for repeatable provisioning).
            *   **Loop**: Go back to **Clean Slate** and repeat.

4.  **Finalization**:
    *   **Cleanup**: `make stop` if testing, or leave running if deploying.
    *   **Update Documentation**: Update `README.md` via `/update_documentation`.
    *   **Notify User**: Confirm success.
