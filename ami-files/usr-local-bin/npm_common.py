#!/usr/bin/env python3
"""
Shared utility functions for NPM management scripts.

This module provides common functionality for npm-init.py and npm-helper,
including database operations, password management, and system utilities.
"""

import os
import time
import sqlite3
import secrets
import bcrypt
import subprocess
from pathlib import Path


# Configurable admin email (override via environment variable)
# Default: admin@example.com (matches NPM's default admin user)
ADMIN_EMAIL = os.environ.get("NPM_ADMIN_EMAIL", "admin@example.com")


# Custom exceptions
class AdminUserNotFoundError(Exception):
    """Raised when the admin user cannot be found in the database."""
    pass


class AuthRecordNotFoundError(Exception):
    """Raised when the password auth record cannot be found or updated."""
    pass


class DatabaseTimeoutError(Exception):
    """Raised when waiting for database exceeds the timeout."""
    pass


def wait_for_db(db_path: str, timeout_seconds: int = 300, interval_seconds: int = 5) -> None:
    """
    Poll for database file existence and readability.
    
    Args:
        db_path: Path to the SQLite database file
        timeout_seconds: Maximum time to wait in seconds (default 300)
        interval_seconds: Time between checks in seconds (default 5)
    
    Raises:
        DatabaseTimeoutError: If database is not ready within timeout
    """
    db_file = Path(db_path)
    start_time = time.time()
    
    while time.time() - start_time < timeout_seconds:
        if db_file.exists() and db_file.is_file():
            try:
                # Try to open the database to ensure it's readable
                conn = sqlite3.connect(str(db_path))
                conn.close()
                return
            except sqlite3.Error:
                # Database exists but not yet readable, continue waiting
                pass
        
        time.sleep(interval_seconds)
    
    raise DatabaseTimeoutError(
        f"Database {db_path} not ready after {timeout_seconds} seconds"
    )


def get_sqlite_connection(db_path: str) -> sqlite3.Connection:
    """
    Get a SQLite connection with Row factory enabled.
    
    Args:
        db_path: Path to the SQLite database file
    
    Returns:
        sqlite3.Connection with row_factory set to sqlite3.Row
    """
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    return conn


def generate_password(length: int = 24) -> str:
    """
    Generate a cryptographically secure random password.
    
    Args:
        length: Desired password length (default 24)
    
    Returns:
        Random password string
    """
    # Safe charset: alphanumeric plus common special characters
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    password = ''.join(secrets.choice(alphabet) for _ in range(length))
    return password


def hash_password(plaintext: str) -> str:
    """
    Hash a password using bcrypt.
    
    Args:
        plaintext: Plain text password to hash
    
    Returns:
        Bcrypt hash as UTF-8 string
    """
    # Generate bcrypt hash with cost factor 12
    salt = bcrypt.gensalt(rounds=12)
    hashed = bcrypt.hashpw(plaintext.encode('utf-8'), salt)
    return hashed.decode('utf-8')


def get_admin_user_id(conn: sqlite3.Connection, email: str = None) -> int:
    """
    Look up the admin user ID from the user table by email.
    
    Args:
        conn: SQLite connection (with Row factory)
        email: Email address to look up (default: ADMIN_EMAIL from environment or "admin@example.com")
    
    Returns:
        User ID (integer)
    
    Raises:
        AdminUserNotFoundError: If user with given email is not found
    """
    if email is None:
        email = ADMIN_EMAIL
    cursor = conn.cursor()
    cursor.execute("SELECT id FROM user WHERE email = ?", (email,))
    row = cursor.fetchone()
    
    if not row:
        raise AdminUserNotFoundError(f"Admin user with email '{email}' not found in database")
    
    return row['id']


def set_admin_password(conn: sqlite3.Connection, user_id: int, hashed_password: str) -> None:
    """
    Update the admin user's password in the auth table.
    
    Args:
        conn: SQLite connection
        user_id: User ID to update
        hashed_password: Bcrypt hash of the new password
    
    Raises:
        AuthRecordNotFoundError: If no password auth record is found or updated
    """
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE auth SET secret = ? WHERE user_id = ? AND type = 'password'",
        (hashed_password, user_id)
    )
    
    if cursor.rowcount == 0:
        raise AuthRecordNotFoundError(
            f"No password auth record found or updated for user_id {user_id}"
        )
    
    conn.commit()


def write_credentials_file(path: str, username: str, password: str) -> None:
    """
    Write credentials to a file with restricted permissions.
    
    Args:
        path: File path to write credentials to
        username: Username to write
        password: Password to write
    
    Raises:
        OSError: If file cannot be written or permissions cannot be set
    """
    cred_file = Path(path)
    cred_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(cred_file, 'w') as f:
        f.write(f"Username: {username}\n")
        f.write(f"Password: {password}\n")
    
    # Set root-only permissions (600)
    os.chmod(cred_file, 0o600)
    # Ensure root ownership (safe when run as root)
    try:
        os.chown(cred_file, 0, 0)
    except PermissionError:
        # If not running as root, leave ownership unchanged
        pass


def detect_instance_ip() -> str:
    """
    Detect the instance IP address.
    
    Tries EC2 metadata endpoint first, then falls back to hostname command.
    
    Returns:
        IP address string, or "unknown" if detection fails
    """
    # Try EC2 metadata endpoint for public IP
    try:
        result = subprocess.run(
            ["curl", "-s", "http://169.254.169.254/latest/meta-data/public-ipv4"],
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception:
        pass
    
    # Fallback to hostname -I
    try:
        result = subprocess.run(
            ["hostname", "-I"],
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0 and result.stdout.strip():
            # Get first IP address
            ip = result.stdout.strip().split()[0]
            return ip
    except Exception:
        pass
    
    return "unknown"


def build_motd_script(ip: str, username: str, password: str) -> str:
    """
    Build the MOTD script content for /etc/update-motd.d/50-npm-info.
    
    Args:
        ip: Instance IP address (or "unknown")
        username: Admin username
        password: Admin password
    
    Returns:
        Complete bash script content as string
    """
    admin_url = f"http://{ip}:81" if ip != "unknown" else "http://<instance-ip>:81"
    
    script_content = f"""#!/bin/bash
# Nginx Proxy Manager Premium AMI - Login Information
# This file is auto-generated by npm-init.py

if [ -f /var/lib/npm-init-complete ]; then
    STATE_DIR="/var/lib/northstar/npm"
    CREDS_SHOWN_MARKER="${{STATE_DIR}}/credentials-motd-shown"
    mkdir -p "$STATE_DIR" >/dev/null 2>&1 || true
    chmod 0750 "$STATE_DIR" >/dev/null 2>&1 || true

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Nginx Proxy Manager – Hardened Edition (Ubuntu 22.04) by Northstar Cloud Solutions"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Admin URL:     {admin_url}"
    echo "  Username:      {username}"
    if [ ! -f "$CREDS_SHOWN_MARKER" ]; then
        echo "  Password:      {password}"
        echo ""
        echo "  Credentials file: /root/npm-admin-credentials.txt"
        # Mark as displayed so credentials are not re-printed on future logins
        : > "$CREDS_SHOWN_MARKER" 2>/dev/null || true
        chmod 0640 "$CREDS_SHOWN_MARKER" 2>/dev/null || true
        chown root:root "$CREDS_SHOWN_MARKER" 2>/dev/null || true
    else
        echo "  Password:      (not displayed)"
        echo ""
        echo "  Note: credentials are shown only on the first SSH login."
    fi
    echo ""
    echo "  Onboarding Checklist:"
    echo "  1. Log into NPM and immediately change the admin password"
    echo "  2. Configure your first Proxy Host"
    echo "  3. (Optional) Set up HTTPS with Let's Encrypt"
    echo "  4. Configure periodic backups using npm-backup"
    echo ""
    echo "  Security expectations:"
    echo "  - Open ports by default: 22/80/81/443"
    echo "  - SSH keys only; root login disabled"
    echo "  - Rotate the admin password after first login"
    echo "  - CloudWatch shipping requires an optional instance role (IAM) for logs/metrics"
    echo ""
    echo "  For help: Run 'npm-helper status' to check system status"
    echo "            Run 'npm-helper show-admin' for username and status"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi
"""
    return script_content

