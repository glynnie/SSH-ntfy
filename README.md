<img width="200" alt="image" src="https://github.com/user-attachments/assets/a7e94c02-bf96-4ccd-9185-293fe5a32c5c" />


# SSH-ntfy
Automated script to install a SSH login/logout alert using PAM + ntfy 
This script sets up automatic **SSH login and logout alerts** using [ntfy](https://ntfy.sh).
Whenever someone logs into or out of your server via SSH, you’ll get a push-style notification in your chosen ntfy topic.

***

## 📦 What this script does

- Creates a secure helper script in `/etc/pam.scripts` that sends ntfy alerts on SSH login and logout using `pam_exec`.
- Backs up your `/etc/pam.d/sshd` file before changing anything
- Adds a `session optional pam_exec.so` line to `sshd`’s PAM config so the helper script runs automatically.
- Prompts you for your **ntfy topic URL**, encouraging a long, random topic for privacy.

***

## 🧩 Requirements

- Linux system using PAM with `/etc/pam.d/sshd` (most modern distros).
- `curl` installed (used to send requests to ntfy).
- Root access (the script edits PAM config and writes to `/etc`).

***

## ▶️ Installation

1. **Save the script**

Save the installer as `ssh_ntfy_pam_install.sh`:

```bash
nano ssh_ntfy_pam_install.sh
# Paste the full script here, then save and exit
```

2. **Make it executable**

```bash
chmod +x ssh_ntfy_pam_install.sh
```

3. **Run as root**

```bash
sudo ./ssh_ntfy_pam_install.sh
```

4. **Enter your ntfy topic URL**

When prompted:
    - Paste a full URL like:
`https://ntfy.sh/this-is-a-very-long-random-topic-name-1234567890`
    - Longer and more random topics are harder to guess and are recommended.

The script will:

- Create `/etc/pam.scripts/ssh_ntfy_alert.sh`.
- Back up `/etc/pam.d/sshd` to a timestamped `.bak.*` file.
- Append a `pam_exec` line to call the helper script for SSH sessions.

***

## 🧪 How to test

1. From another machine, SSH into the server:

```bash
ssh youruser@your-server
```

2. Check your ntfy topic (web UI, app, or `curl`) and confirm:
    - A **login** message when the session opens.
    - A **logout** message after you exit the SSH session.
3. If you see no messages:
    - Check `/var/log/auth.log` or `/var/log/secure` for `pam_exec` or script errors.
    - Make sure `/etc/pam.scripts/ssh_ntfy_alert.sh` is executable and owned by root.

***

## 🛠️ Uninstall / revert

If you want to undo changes:

1. Restore the backup PAM file:

```bash
sudo cp /etc/pam.d/sshd.bak.YYYYMMDDHHMMSS /etc/pam.d/sshd
```

2. Optionally remove the helper script and directory:

```bash
sudo rm -f /etc/pam.scripts/ssh_ntfy_alert.sh
sudo rmdir /etc/pam.scripts 2>/dev/null || true
```


This returns your SSH PAM configuration to its state before the script ran.
