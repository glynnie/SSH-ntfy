<img width="100" alt="image" src="https://github.com/user-attachments/assets/a7e94c02-bf96-4ccd-9185-293fe5a32c5c" />

# **SSH-ntfy**

Automated scripts to implement either **SSH login/logout alerts** or a full **2FA SSH Gatekeeper** using PAM and [ntfy](https://ntfy.sh).  
Depending on your security needs, you can choose between simple notifications or an interactive approval system that blocks access until you tap a button on your phone.

# ---

# **🚀 Choose Your Level of Security**

| Feature | Alerts Only (ssh\_ntfy\_pam\_install.sh) | The Gatekeeper (install\_ntfy\_gatekeeper.sh) |
| :---- | :---- | :---- |
| **Function** | Sends a notification when someone logs in/out. | **Blocks** login until you tap "Approve" on your phone. |
| **Interaction** | Passive (informative). | Active (2FA/MFA). |
| **Impact** | Minimal. Connection is instant. | User hangs at "Connecting..." until approved. |
| **Whitelist** | N/A. | Remembers approved IPs for 24 hours. |

# ---

# **📦 What these scripts do**

## **Option A: Alerts Only**

* Creates a helper script in /etc/pam.scripts that sends ntfy alerts on SSH session open and close.  
* Backs up your /etc/pam.d/sshd file.  
* Adds an optional PAM line so logins proceed even if the notification fails.

## **Option B: The Gatekeeper (2FA)**

* Implements a **blocking** 2FA challenge at the start of the SSH handshake.  
* Uses auth requisite to ensure the login **fails immediately** if "Deny" is pressed or the 45-second timer expires.  
* Generates unique session IDs to prevent replay attacks and filtered polling to avoid false positives.  
* Creates a local trust directory (/var/lib/ssh-ntfy) to whitelist your IP for 24 hours after one successful approval.

# ---

# **🧩 Requirements**

* **System:** Linux using PAM with /etc/pam.d/sshd (Arch, Debian, Ubuntu, etc.).  
* **Tools:** curl and bash installed.  
* **Access:** Root privileges.  
* **App:** The [ntfy mobile app](https://www.google.com/search?q=https://ntfy.sh/%23download) installed on your phone.  
* **Config:** Ensure UsePAM yes and KbdInteractiveAuthentication yes are set in /etc/ssh/sshd\_config.

# ---

# **▶️ Installation**

## **1\. Save your chosen script**

Save either ssh\_ntfy\_pam\_install.sh (Alerts) or install\_ntfy\_gatekeeper.sh (Gatekeeper) to your server.

## **2\. Make it executable**

Bash

chmod \+x your\_chosen\_script.sh

## **3\. Run as root**

Bash

sudo ./your\_chosen\_script.sh

## **4\. Configuration Prompts**

* **Alerts Script:** Enter your full ntfy topic URL (e.g., https://ntfy.sh/my\_secret\_alerts).  
* **Gatekeeper Script:** Enter just the **Topic Name** (e.g., my\_secret\_gatekeeper). The script will handle the rest.

# ---

# **🧪 How to test**

## **For Option A (Alerts):**

1. SSH into your server: ssh user@server-ip.  
2. Confirm you receive a "SSH login" notification on your phone immediately.

## **For Option B (Gatekeeper):**

1. **Clear old whitelists:** sudo rm \-f /var/lib/ssh-ntfy/\*.  
2. **Attempt login:** The terminal should "hang" and not ask for a password yet.  
3. **Check Phone:** You will receive a notification with **Approve** and **Deny** buttons.  
4. **Action:** \- Tap **Approve**: The terminal will proceed to the password prompt.  
   * Tap **Deny**: The terminal will immediately close the connection.

# ---

# **🛠️ Maintenance & Debugging**

## **Debugging**

If things aren't working as expected, check the logs:

* **Gatekeeper Logs:** cat /tmp/ntfy\_debug.log  
* **System Logs:** journalctl \-u ssh or tail \-f /var/log/auth.log

## **Uninstall / Revert**

1. **Restore PAM:** Look for the .bak file created in /etc/pam.d/ and move it back:  
   Bash  
   sudo cp /etc/pam.d/sshd.bak.YYYYMMDDHHMMSS /etc/pam.d/sshd

2. **Remove Scripts:**  
   Bash  
   sudo rm \-rf /etc/pam.scripts  
   sudo rm \-rf /var/lib/ssh-ntfy  

