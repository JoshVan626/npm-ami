#!/usr/bin/env python3
"""
Nginx Proxy Manager First-Boot Initialization Script

This script runs once per instance to:
1. Wait for the NPM SQLite database to be initialized
2. Generate a strong random admin password
3. Update the admin user's password in the SQLite database
4. Store credentials in a root-only file
5. Update the MOTD with login information
6. Create a marker file to prevent re-running

This script is called by npm-init.service (systemd) after npm.service starts.
"""

import os
import sys
import logging
from pathlib import Path

# Import shared utilities
from npm_common import (
    wait_for_db,
    get_sqlite_connection,
    generate_password,
    hash_password,
    get_admin_user_id,
    set_admin_password,
    write_credentials_file,
    detect_instance_ip,
    build_motd_script,
    AdminUserNotFoundError,
    AuthRecordNotFoundError,
    DatabaseTimeoutError,
)

# Configuration constants
MARKER_FILE = Path("/var/lib/npm-init-complete")
DB_PATH = Path("/opt/npm/data/database.sqlite")
CREDENTIALS_FILE = Path("/root/npm-admin-credentials.txt")
MOTD_SCRIPT = Path("/etc/update-motd.d/50-npm-info")
ADMIN_EMAIL = "admin@example.com"

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.StreamHandler(sys.stderr)
    ]
)
logger = logging.getLogger(__name__)


def check_marker_file():
    """Check if initialization has already been completed."""
    if MARKER_FILE.exists():
        logger.info(f"Marker file {MARKER_FILE} exists. Initialization already completed.")
        sys.exit(0)


def update_admin_password(db_path, password):
    """
    Update the admin user's password in the NPM SQLite database.
    
    Args:
        db_path: Path to the SQLite database
        password: Plain text password to set
    
    Returns:
        True if successful, False otherwise
    """
    try:
        # Hash the password
        password_hash = hash_password(password)
        logger.info("Password hashed successfully.")
        
        # Get database connection with Row factory
        conn = get_sqlite_connection(str(db_path))
        
        try:
            # Find the admin user by email
            user_id = get_admin_user_id(conn, ADMIN_EMAIL)
            logger.info(f"Found admin user with ID: {user_id}")
            
            # Update the password in auth table
            set_admin_password(conn, user_id, password_hash)
            logger.info("Admin password updated successfully in database.")
            return True
            
        except AdminUserNotFoundError as e:
            logger.error(f"Admin user not found: {e}")
            return False
        except AuthRecordNotFoundError as e:
            logger.error(f"Auth record not found: {e}")
            return False
        finally:
            conn.close()
        
    except Exception as e:
        logger.error(f"Unexpected error while updating password: {e}")
        return False


def update_motd(password):
    """
    Update the MOTD script with login information.
    
    Args:
        password: Admin password
    """
    try:
        # Detect instance IP
        ip = detect_instance_ip()
        logger.info(f"Detected instance IP: {ip}")
        
        # Build MOTD script content using shared function
        motd_content = build_motd_script(ip, ADMIN_EMAIL, password)
        
        # Write MOTD script
        with open(MOTD_SCRIPT, 'w') as f:
            f.write(motd_content)
        
        # Make MOTD script executable
        os.chmod(MOTD_SCRIPT, 0o755)
        logger.info(f"MOTD script updated at {MOTD_SCRIPT}")
        
    except Exception as e:
        logger.error(f"Failed to update MOTD: {e}")
        raise


def create_marker_file():
    """Create the marker file to prevent re-running."""
    try:
        MARKER_FILE.parent.mkdir(parents=True, exist_ok=True)
        MARKER_FILE.touch()
        logger.info(f"Marker file created: {MARKER_FILE}")
    except Exception as e:
        logger.error(f"Failed to create marker file: {e}")
        raise


def main():
    """Main execution function."""
    logger.info("Starting NPM initialization...")
    
    # Check if already initialized
    check_marker_file()
    
    # Wait for database to be ready
    try:
        logger.info(f"Waiting for database at {DB_PATH} to be available...")
        wait_for_db(str(DB_PATH))
        logger.info(f"Database {DB_PATH} is ready.")
    except DatabaseTimeoutError as e:
        logger.error(f"Database initialization failed: {e}")
        sys.exit(1)
    
    # Generate password
    password = generate_password()
    logger.info("Generated new admin password.")
    
    # Update database
    if not update_admin_password(DB_PATH, password):
        logger.error("Failed to update admin password in database. Exiting.")
        sys.exit(1)
    
    # Write credentials file
    try:
        write_credentials_file(str(CREDENTIALS_FILE), ADMIN_EMAIL, password)
        logger.info(f"Credentials written to {CREDENTIALS_FILE}")
    except Exception as e:
        logger.error(f"Failed to write credentials file: {e}")
        sys.exit(1)
    
    # Update MOTD
    try:
        update_motd(password)
    except Exception as e:
        logger.error(f"Failed to update MOTD: {e}")
        sys.exit(1)
    
    # Create marker file
    create_marker_file()
    
    logger.info("NPM initialization completed successfully!")
    sys.exit(0)


if __name__ == "__main__":
    main()

