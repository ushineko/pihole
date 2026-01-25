---
description: Update the project documentation (README.md) based on file changes.
---

1.  **Preparation**:
    *   **Identify Changes**: What files have been modified in the current session?
        *   `docker-compose.yml`: Did ports, volumes, or environment variables change?
        *   `Makefile`: Were new targets added or existing ones modified?
        *   `etc-dnsmasq.d/*.conf`: Did the custom DNS configuration change?

2.  **Analyze & Update**:
    *   **Configuration**:
        *   If `docker-compose.yml` changed, check if the "Configuration" or "Auto-start Configuration" sections in `README.md` need updates.
    *   **Commands**:
        *   If `Makefile` changed, update the "Makefile Usage" section in `README.md` to reflect new or changed commands.
    *   **Features**:
        *   If new features were added (e.g., new scripts), ensure they are mentioned in "Features" or a relevant new section.

3.  **Execution**:
    *   **Edit `README.md`**: Apply the necessary changes.
    *   **Verify**: Ensure the markdown is valid and the information is accurate.

4.  **Finalization**:
    *   **Notify User**: Mention that documentation has been updated to reflect recent changes.
