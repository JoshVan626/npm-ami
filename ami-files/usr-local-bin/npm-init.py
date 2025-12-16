#!/usr/bin/env python3
"""Nginx Proxy Manager First-Boot Initialization Script (Rescue Version)

This version is designed to avoid hanging forever if the database is created but
not seeded correctly. It uses bounded waits and can force-seed the admin user if
missing.
"""

import logging
import os
import sqlite3
import sys
import time
from pathlib import Path

# Import shared utilities
from npm_common import (
    ADMIN_EMAIL,
    build_motd_script,
    detect_instance_ip,
    generate_password,
    get_admin_user_id,
    get_sqlite_connection,
    hash_password,
    set_admin_password,
    write_credentials_file,
)

# Configuration constants
MARKER_FILE = Path("/var/lib/npm-init-complete")
DB_PATH = Path("/opt/npm/data/database.sqlite")
CREDENTIALS_FILE = Path("/root/npm-admin-credentials.txt")
MOTD_SCRIPT = Path("/etc/update-motd.d/50-npm-info")

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout), logging.StreamHandler(sys.stderr)],
)
logger = logging.getLogger(__name__)


def simple_wait_for_file(path: Path, timeout: int = 60) -> bool:
    """Wait for the DB file to be created on disk and be non-empty."""
    start = time.time()
    logger.info("Waiting for %s to appear...", path)
    while time.time() - start < timeout:
        try:
            if path.exists() and path.stat().st_size > 0:
                logger.info("Database file found.")
                return True
        except FileNotFoundError:
            pass
        time.sleep(1)
    return False


def ensure_admin_user_exists(conn: sqlite3.Connection, email: str, password_hash: str) -> bool:
    """Ensure the admin user exists.

    If the user table is not ready yet, return False so the caller can retry.
    If the user is missing, attempt to insert a minimal admin user + auth record
    and permissions (rescue seeding).
    """
    cursor = conn.cursor()

    # Check if user table exists
    try:
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='user';")
        if not cursor.fetchone():
            logger.warning("User table not found yet. Retrying...")
            return False

        cursor.execute('SELECT id FROM "user" WHERE email = ?', (email,))
        if cursor.fetchone():
            logger.info("User %s exists.", email)
            return True
    except sqlite3.OperationalError as e:
        logger.warning("DB locked or not ready: %s", e)
        return False

    logger.warning("User %s missing! Attempting to force-seed database...", email)
    try:
        now_ms = int(time.time() * 1000)

        # Insert admin user
        cursor.execute(
            """
            INSERT INTO "user" (created_on, modified_on, is_deleted, email, name, nickname, avatar, roles)
            VALUES (?, ?, 0, ?, 'Administrator', 'Admin', '', '["admin"]')
            """,
            (now_ms, now_ms, email),
        )
        user_id = cursor.lastrowid

        # Insert password auth record
        cursor.execute(
            """
            INSERT INTO auth (created_on, modified_on, user_id, type, secret, meta)
            VALUES (?, ?, ?, 'password', ?, '{}')
            """,
            (now_ms, now_ms, user_id, password_hash),
        )

        # Insert permissions row
        cursor.execute(
            """
            INSERT INTO user_permission (
              created_on, modified_on, user_id, visibility,
              proxy_hosts, redirection_hosts, dead_hosts, streams,
              access_lists, certificates, proxy_providers
            )
            VALUES (?, ?, ?, 'all', 'manage', 'manage', 'manage', 'manage', 'manage', 'manage', 'manage')
            """,
            (now_ms, now_ms, user_id),
        )

        conn.commit()
        logger.info("Force-seeded user %s with ID %s", email, user_id)
        return True
    except Exception as e:
        logger.error("Seeding failed: %s", e)
        try:
            conn.rollback()
        except Exception:
            pass
        return False


def main() -> None:
    logger.info("Starting NPM initialization (Rescue Mode)...")

    if MARKER_FILE.exists():
        logger.info("Initialization already completed.")
        sys.exit(0)

    # 1) Wait for the DB file (loose check)
    if not simple_wait_for_file(DB_PATH, timeout=60):
        logger.error("Database file never appeared. Aborting.")
        sys.exit(1)

    # Generate password
    password = generate_password()
    password_hash = hash_password(password)

    # 2) Loop until we can connect and seed/update (bounded)
    success = False
    deadline = time.time() + 60

    while time.time() < deadline:
        conn = None
        try:
            conn = get_sqlite_connection(str(DB_PATH))

            if ensure_admin_user_exists(conn, ADMIN_EMAIL, password_hash):
                user_id = get_admin_user_id(conn, ADMIN_EMAIL)
                set_admin_password(conn, user_id, password_hash)
                success = True
                break
        except Exception as e:
            logger.warning("Retry: %s", e)
        finally:
            if conn is not None:
                try:
                    conn.close()
                except Exception:
                    pass

        time.sleep(2)

    if not success:
        logger.error("Could not seed/update database after retries.")
        sys.exit(1)

    # 3) Finalize
    try:
        write_credentials_file(str(CREDENTIALS_FILE), ADMIN_EMAIL, password)

        ip = detect_instance_ip()
        motd_content = build_motd_script(ip, ADMIN_EMAIL, password)
        with open(MOTD_SCRIPT, "w", encoding="utf-8") as f:
            f.write(motd_content)
        os.chmod(MOTD_SCRIPT, 0o755)

        MARKER_FILE.parent.mkdir(parents=True, exist_ok=True)
        MARKER_FILE.touch()

        logger.info("NPM initialization completed successfully!")
    except Exception as e:
        logger.error("Finalization failed: %s", e)
        sys.exit(1)


if __name__ == "__main__":
    main()
