#!/bin/bash
# install_public_ntfy_gatekeeper.sh
# Automates installation of a SSH 2FA Gatekeeper for PUBLIC ntfy.sh topics

set -e

# --- Constants ---
SCRIPT_INSTALL_DIR="/etc/pam.scripts"
SCRIPT_NAME="ssh_ntfy_gatekeeper.sh"
FULL_SCRIPT_PATH="${SCRIPT_INSTALL_DIR}/${SCRIPT_NAME}"
PAM_FILE="/etc/pam.d/sshd"
TRUST_DIR="/var/lib/ssh-ntfy"

# --- Root Check ---
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root." >&2
  exit 1
fi

echo "=============================================="
echo "   SSH Public ntfy.sh Gatekeeper Installer"
echo "=============================================="
echo "WARNING: You are using a PUBLIC ntfy.sh topic."
echo "Anyone who knows the topic name can approve logins."
echo "Please use a long, random, secret topic name."
echo "=============================================="
echo

# --- Configuration Prompts ---

echo "1. Enter your Secret Topic Name"
echo "   (e.g., my_secret_ssh_login_992834)"
read -r -p "Topic Name: " TOPIC_NAME

if [ -z "${TOPIC_NAME}" ]; then 
    echo "Topic name required. Aborting."
    exit 1
fi

echo
echo "----------------------------------------------"
echo "Configuring for: https://ntfy.sh/${TOPIC_NAME}"
echo "----------------------------------------------"
echo

# --- Step 1: Create Directories ---
echo "Creating directories..."
mkdir -p "${SCRIPT_INSTALL_DIR}"
chmod 0755 "${SCRIPT_INSTALL_DIR}"

mkdir -p "${TRUST_DIR}"
chmod 0700 "${TRUST_DIR}"
chown root:root "${TRUST_DIR}"

# --- Step 2: Write the Gatekeeper Script ---
echo "Writing Gatekeeper script to ${FULL_SCRIPT_PATH}..."

cat > "${FULL_SCRIPT_PATH}" <<EOF
#!/bin/bash
# SSH Gatekeeper (Public ntfy.sh)

# --- CONFIGURATION ---
TOPIC="${TOPIC_NAME}"
# Direct connection to public ntfy.sh
NTFY_URL="https://ntfy.sh/\${TOPIC}"

TRUST_DIR="${TRUST_DIR}"
REMOTE_IP="\${PAM_RHOST:-unknown}"
IP_FILE="\${TRUST_DIR}/\${REMOTE_IP}"
LOCKFILE="/tmp/ntfy_ssh_\${PAM_USER}.lock" 
DEBUG_LOG="/tmp/ntfy_debug.log"
# ---------------------

# Ensure Whitelist Dir Exists
mkdir -p "\${TRUST_DIR}"

# Debug Logging
echo "--- \$(date) ---" >> "\${DEBUG_LOG}"
echo "User: \${PAM_USER} | IP: \${REMOTE_IP} | Type: \${PAM_TYPE}" >> "\${DEBUG_LOG}"

# 1. Whitelist Check (24h)
if [ -f "\${IP_FILE}" ]; then
    LAST_AUTH=\$(cat "\${IP_FILE}")
    NOW=\$(date +%s)
    if (( NOW - LAST_AUTH < 86400 )); then
        echo "Whitelist valid. Allowing." >> "\${DEBUG_LOG}"
        exit 0
    fi
fi

# 2. Lockfile Check
if [ -e "\${LOCKFILE}" ]; then
    echo "Lockfile active. Skipping." >> "\${DEBUG_LOG}"
    exit 0
fi
touch "\${LOCKFILE}"
trap "rm -f \${LOCKFILE}" EXIT

# 3. Unique Login ID
LOGIN_ID="\$(date +%s)_\$RANDOM"

# 4. Send Push Notification
# We send a POST to ntfy.sh. No credentials needed for public topics.
curl -s -o /dev/null \\
     -H "Title: SSH Approval Required" \\
     -H "Priority: urgent" \\
     -H "Actions: http, Approve, \${NTFY_URL}/publish?message=yes_\${LOGIN_ID}; http, Deny, \${NTFY_URL}/publish?message=no_\${LOGIN_ID}" \\
     -d "Login: \${PAM_USER} from \${REMOTE_IP}" \\
     "\${NTFY_URL}"

echo "Notification sent. ID: \${LOGIN_ID}" >> "\${DEBUG_LOG}"

# 5. Wait for Response (Polling)
# Capture time to ignore old cached messages
POLL_START=\$(date +%s)

for (( i=0; i<45; i++ )); do
    # Poll ntfy.sh for JSON messages since POLL_START
    RESPONSE=\$(curl -s "\${NTFY_URL}/json?poll=1&since=\${POLL_START}")

    # STRICT MATCH: Look for the JSON "message" field specifically
    if echo "\${RESPONSE}" | grep -q "\"message\":\"yes_\${LOGIN_ID}\""; then
        echo "MATCH: Approved ID \${LOGIN_ID}" >> "\${DEBUG_LOG}"
        date +%s > "\${IP_FILE}"
        exit 0
    elif echo "\${RESPONSE}" | grep -q "\"message\":\"no_\${LOGIN_ID}\""; then
        echo "MATCH: Denied ID \${LOGIN_ID}. Killing \${PPID}." >> "\${DEBUG_LOG}"
        rm -f "\${IP_FILE}"
        kill -9 "\${PPID}" > /dev/null 2>&1
        exit 1
    fi
    sleep 1
done

echo "Timeout. Terminating session." >> "\${DEBUG_LOG}"
kill -9 "\${PPID}" > /dev/null 2>&1
exit 1
EOF

# Set permissions
chmod 0700 "${FULL_SCRIPT_PATH}"
chown root:root "${FULL_SCRIPT_PATH}"
echo "Script created successfully."

# --- Step 3: Configure PAM ---
echo "Configuring PAM (${PAM_FILE})..."

# Backup PAM config
if [ -f "${PAM_FILE}" ]; then
  BACKUP="${PAM_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  echo "Backing up ${PAM_FILE} to ${BACKUP}"
  cp "${PAM_FILE}" "${BACKUP}"
else
  echo "Error: PAM file ${PAM_FILE} not found." >&2
  exit 1
fi

# Clean up old references if re-installing
sed -i "\|${SCRIPT_NAME}|d" "${PAM_FILE}"

# Insert the line at the VERY TOP (Line 2, after the PAM header)
# 'auth requisite' ensures it runs BEFORE the password check and has veto power.
sed -i "2i auth      requisite pam_exec.so seteuid ${FULL_SCRIPT_PATH}" "${PAM_FILE}"

echo "PAM configuration updated."
echo "The Gatekeeper is now the FIRST check in the auth stack."

echo
echo "=============================================="
echo "   Installation Complete"
echo "=============================================="
echo "Next Steps:"
echo "1. Run as root/sudo           rm /var/lib/ssh-ntfy/*     (To clear any old whitelists)"
echo "2. Subscribe to your topic on your phone: ${TOPIC_NAME}"
echo "3. Open a NEW terminal window (keep this one open!)"
echo "4. SSH into this server to test."
echo "YOU MUST ENSURE THESE LINES ARE SET IN YOUR /etc/ssh/sshd_config"
echo "UsePAM yes"
echo "KbdInteractiveAuthentication yes"
echo "=============================================="
