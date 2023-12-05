#!/bin/bash

## Check if backup folder is provided
if [ -z "$1" ]; then
    echo "Please provide the backup folder as an argument."
    exit 1
fi

# Define the variables
MOODLE_ROOT_DIR="/var/www/"
LOG_FILE="${MOODLE_ROOT_DIR}/MoodleRestoreLogs.log"
SERVICES=("mariadb" "mysql" "nginx" "apache2")
BACKUP_DIR="$1"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "${LOG_FILE}"
}

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    log_message "Backup directory '$BACKUP_DIR' does not exist."
    exit 1
fi

# Extract Moodle directory and data
LATEST_MOODLE_DIR=$(ls -Art "$BACKUP_DIR"/moodle_*.tar.gz | tail -n 1)
if [ -f "$LATEST_MOODLE_DIR" ]; then
    log_message "Extracting Moodle directory: $LATEST_MOODLE_DIR"
    tar -xzf "$BACKUP_DIR/$LATEST_MOODLE_DIR" -C "$MOODLE_ROOT_DIR"
else
    log_message "Unable to find the latest Moodle directory archive."
    exit 1
fi

LATEST_MOODLEDATA_DIR=$(ls -Art "$BACKUP_DIR"/moodledata_*.tar.gz | tail -n 1)
if [ -f "$LATEST_MOODLEDATA_DIR" ]; then
    log_message "Extracting Moodle directory: $LATEST_MOODLEDATA_DIR"
    tar -xzf "$BACKUP_DIR/$LATEST_MOODLEDATA_DIR" -C "$MOODLE_ROOT_DIR"
else
    log_message "Unable to find the latest Moodle directory archive."
    exit 1
fi

# Restore Moodle database
LATEST_DATABASE_BACKUP=$(ls -Art "$BACKUP_DIR"/moodle-database_*.sql | tail -n 1)
if [ -f "$LATEST_DATABASE_BACKUP" ]; then
    log_message "Restoring database from: $LATEST_DATABASE_BACKUP"
    
    # Extract database credentials from Moodle configuration
    DBUSER=$(cat "$MOODLE_ROOT_DIR"/moodle/config.php | grep "\$CFG->dbuser" | cut -d "'" -f 2)
    DBPASS=$(cat "$MOODLE_ROOT_DIR"/moodle/config.php | grep "\$CFG->dbpass" | cut -d "'" -f 2)
    DBNAME=$(cat "$MOODLE_ROOT_DIR"/moodle/config.php | grep "\$CFG->dbname" | cut -d "'" -f 2)
    
    # Check if database user exists
    if [ $(mysql -u "$2" -p"$3" -e "SELECT User FROM mysql.user;" | grep -c "$DBUSER") -eq 0 ]; then
        log_message "Creating Moodle database user: $DBUSER"
        mysql -u "$2" -p"$3" -e "CREATE USER $DBUSER@localhost IDENTIFIED BY '$DBPASS'; GRANT ALL PRIVILEGES ON *.* TO $DBUSER@localhost;"
        else
        log_message "Unable to create Moodle database user"
        exit 1;
    fi
    
    # Check if database exists
    if [ $(mysql -u "$2" -p"$3" -e "SHOW DATABASES;" | grep -c "$DBNAME") -eq 0 ]; then
        log_message "Creating Moodle database: $DBNAME"
        mysql -u "$DBUSER" -p"$DBPASS" -e "CREATE DATABASE $DBNAME;"
        else
        log_message "Unable to create Moodle database"
        exit 1;
    fi
    
    # Import Moodle database backup
    log_message "Importing Moodle database backup: $LATEST_DATABASE_BACKUP"
    mysql -u "$DBUSER" -p"$DBPASS" $DBNAME < "$LATEST_DATABASE_BACKUP"
else
    log_message "Unable to find the latest Moodle database archive"
    exit 1;
fi
