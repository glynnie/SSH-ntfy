#!/bin/bash
# ssh_ntfy_pam_install.sh
# Automate PAM + ntfy SSH login/logout alerts

set -e

PAM_SCRIPT_DIR="/etc/pam.scripts"
PAM_SCRIPT="${PAM_SCRIPT_DIR}/ssh_ntfy_alert.sh"
PAM_FILE="/etc/pam.d/sshd"

# Require root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

echo "=== ntfy topic configuration ==="
echo "Enter the FULL ntfy topic URL to use for alerts."
echo "Example:"
echo "  https://ntfy.sh/this-is-a-very-long-random-topic-name-1234567890"
echo
read -r -p "ntfy topic URL: " NTFY_TOPIC_URL

# Basic validation
if [ -z "${NTFY_TOPIC_URL}" ]; then
  echo "No ntfy topic URL provided; aborting." >&2
  exit 1
fi

case "${NTFY_TOPIC_URL}" in
  http://*|https://*)
    ;;
  *)
    echo "The ntfy topic URL should start with http:// or https://; aborting." >&2
    exit 1
    ;;
esac

echo "Using ntfy topic: ${NTFY_TOPIC_URL}"
echo

echo "Creating PAM helper script directory: ${PAM_SCRIPT_DIR}"
mkdir -p "${PAM_SCRIPT_DIR}"
chmod 0755 "${PAM_SCRIPT_DIR}"
chown root:root "${PAM_SCRIPT_DIR}"

echo "Writing PAM helper script: ${PAM_SCRIPT}"
# Use double quotes for cat <<EOF so we can expand ${NTFY_TOPIC_URL} into the file
cat > "${PAM_SCRIPT}" <<EOF
#!/bin/bash

# Send an ntfy alert for each SSH session open/close
case "\${PAM_TYPE}" in
  open_session)
    curl \\
      -H "prio: high" \\
      -H "tags: warning" \\
      -d "SSH login: \${PAM_USER} \\
      "${NTFY_TOPIC_URL}"
    ;;
  close_session)
    curl \\
      -H "prio: low" \\
      -H "tags: info" \\
      -d "SSH logout: \${PAM_USER} \\
      "${NTFY_TOPIC_URL}"
    ;;
esac

exit 0
EOF

chmod 0700 "${PAM_SCRIPT}"
chown root:root "${PAM_SCRIPT}"

# Backup PAM config
if [ -f "${PAM_FILE}" ]; then
  BACKUP="${PAM_FILE}.bak.\$(date +%Y%m%d%H%M%S)"
  echo "Backing up ${PAM_FILE} to ${BACKUP}"
  cp "${PAM_FILE}" "${BACKUP}"
else
  echo "PAM file ${PAM_FILE} not found; aborting." >&2
  exit 1
fi

# Add pam_exec line if not present
if grep -q "pam_exec.so ${PAM_SCRIPT}" "${PAM_FILE}"; then
  echo "PAM exec line already present in ${PAM_FILE}, skipping edit."
else
  echo "Adding pam_exec line to ${PAM_FILE}"
  cat <<EOF >> "${PAM_FILE}"

# SSH ntfy alert
session optional pam_exec.so ${PAM_SCRIPT}
EOF
fi

echo "Installation complete."
echo "Test by SSH'ing into this host and verifying an ntfy message on ${NTFY_TOPIC_URL}."
