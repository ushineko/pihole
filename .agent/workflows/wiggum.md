---
description: Iteratively run, capture logs, and debug the Pi-hole container until a success condition is met.
---

1.  **Preparation**:
    *   **Identify Goal**: What is the **Success Condition**? (e.g., "Web interface accessible", "DNS resolution works", "Error X is gone from logs").
    *   **Ensure Observability**:
        *   The main source of observation is `make logs` (which runs `docker compose logs -f pihole`).
        *   Alternatively, `make status` shows the container state.

2.  **Clean Slate**:
    *   **Kill Existing Instances**: Before every run, ensure to stop the container to ensure a fresh start.
        *   Run: `make stop` (or `docker compose down`)

3.  **Execution Loop**:
    *   **Run**: Start the container.
        *   Run: `make start` (or `docker compose up -d`)
    *   **Capture**: Check the logs.
        *   Run: `make logs`
        *   *Note*: You might need to wait a few seconds for the container to initialize.
    *   **Analyze**:
        *   Did the **Success Condition** occur?
        *   Are there new errors in the logs?
        *   Is the container status `Up` (check with `make status`)?
    *   **Decision**:
        *   **Success**: If yes, Proceed to **Finalization**.
        *   **Failure**:
            *   Analyze the logs to understand *why*.
            *   **Adjust**: Apply a fix to `custom.conf`, `custom.list`, `docker-compose.yml`, or other configuration files.
            *   **Loop**: Go back to **Clean Slate** and repeat.

4.  **Finalization**:
    *   **Cleanup**:
        *   If the goal was just to test, you might want to `make stop`.
        *   If the goal was to deploy, leave it running.
    *   **Update Documentation**:
        *   If you changed configuration parameters, update `README.md`.
    *   **Notify User**: Confirm success.
