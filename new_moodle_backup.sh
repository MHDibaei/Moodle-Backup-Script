#!/bin/bash

# Check for verbose flag
VERBOSE=0
if [ "$1" == "-v" ] || [ "$1" == "--verbose" ]; then
    VERBOSE=1
fi

# Define the path to Moodle's config.php
CONFIG_FILE="/var/www/moodle/config.php"

# Extract Moodle configuration
DIRROOT=$(dirname $(dirname $CONFIG_FILE))

DBTYPE=$(cat $CONFIG_FILE | grep "\$CFG->dbtype" | cut -d "'" -f 2)
DBUSER=$(cat $CONFIG_FILE | grep "\$CFG->dbuser" | cut -d "'" -f 2)
DBPASS=$(cat $CONFIG_FILE | grep "\$CFG->dbpass" | cut -d "'" -f 2)
DBNAME=$(cat $CONFIG_FILE | grep "\$CFG->dbname" | cut -d "'" -f 2)
DATAROOT=$(cat $CONFIG_FILE | grep "\$CFG->dataroot" | cut -d "'" -f 2)

# Define the backup directory
BACKUP_DIR="${DIRROOT}/moodle-backup"

# Create the backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Define the log file
LOG_FILE="${BACKUP_DIR}/backup.log"

# Function to log messages
log_message() {
    echo "$(date): $1" | tee -a "${LOG_FILE}"
}

# Get the current date
CURRENT_DATE=$(date +%Y%m%d)

# Export the Moodle database
log_message "Starting database export..."
if [ "${DBTYPE}" == "mariadb" ]; then
    if [ "${VERBOSE}" -eq 1 ]; then
        mariadb-dump -v -u "${DBUSER}" -p"${DBPASS}" "${DBNAME}" > "${BACKUP_DIR}/moodle-database_${CURRENT_DATE}.sql"
    else
        mariadb-dump -u "${DBUSER}" -p"${DBPASS}" "${DBNAME}" > "${BACKUP_DIR}/moodle-database_${CURRENT_DATE}.sql"
    fi
    log_message "MariaDB database export completed."
else
    if [ "${VERBOSE}" -eq 1 ]; then
        mysqldump -v -u "${DBUSER}" -p"${DBPASS}" "${DBNAME}" > "${BACKUP_DIR}/moodle-database_${CURRENT_DATE}.sql"
    else
        mysqldump -u "${DBUSER}" -p"${DBPASS}" "${DBNAME}" > "${BACKUP_DIR}/moodle-database_${CURRENT_DATE}.sql"
    fi
    log_message "Database export completed."
fi

# Create an archive of the Moodle directory
log_message "Starting Moodle directory backup..."
if [ "${VERBOSE}" -eq 1 ]; then
    tar -cvzf "${BACKUP_DIR}/moodle_${CURRENT_DATE}.tar.gz" "${DIRROOT}"
else
    tar -czf "${BACKUP_DIR}/moodle_${CURRENT_DATE}.tar.gz" "${DIRROOT}"
fi
log_message "Moodle directory backup completed."

# Create an archive of the Moodle data directory
log_message "Starting Moodle data directory backup..."
if [ "${VERBOSE}" -eq 1 ]; then
    tar -cvzf "${BACKUP_DIR}/moodledata_${CURRENT_DATE}.tar.gz" "${DATAROOT}"
else
    tar -czf "${BACKUP_DIR}/moodledata_${CURRENT_DATE}.tar.gz" "${DATAROOT}"
fi
log_message "Moodle data directory backup completed."

# Delete old backups if there are more than 2
log_message "Checking for old backups..."
BACKUP_COUNT=$(ls -1 "${BACKUP_DIR}"/*.tar.gz "${BACKUP_DIR}"/*.sql | wc -l)
if [ "${BACKUP_COUNT}" -gt 6 ]; then
    log_message "Deleting oldest backup..."
    ls -t "${BACKUP_DIR}"/*.tar.gz "${BACKUP_DIR}"/*.sql | tail -n 1 | xargs rm
    log_message "Oldest backup deleted."
fi

log_message "Backup process completed. All backup files are located in ${BACKUP_DIR}."
