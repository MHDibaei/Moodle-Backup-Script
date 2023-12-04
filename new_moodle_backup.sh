#!/bin/bash

# Check for verbose flag
VERBOSE=0
if [ "$1" == "-v" ] || [ "$1" == "--verbose" ]; then
    VERBOSE=1
fi

# Load Moodle configuration
source /var/www/moodle/config.php

# Define the backup directory
BACKUP_DIR="${CFG->dirroot}/backup"

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
if [ "${CFG->dbtype}" == "mariadb" ]; then
    if [ "${VERBOSE}" -eq 1 ]; then
        mariadb-dump -v -u "${CFG->dbuser}" -p"${CFG->dbpass}" "${CFG->dbname}" > "${BACKUP_DIR}/mariadb-database_${CURRENT_DATE}.sql"
    else
        mariadb-dump -u "${CFG->dbuser}" -p"${CFG->dbpass}" "${CFG->dbname}" > "${BACKUP_DIR}/mariadb-database_${CURRENT_DATE}.sql"
    fi
    log_message "Database export completed."
else
    if [ "${VERBOSE}" -eq 1 ]; then
        mysqldump -v -u "${CFG->dbuser}" -p"${CFG->dbpass}" "${CFG->dbname}" > "${BACKUP_DIR}/moodle-database_${CURRENT_DATE}.sql"
    else
        mysqldump -u "${CFG->dbuser}" -p"${CFG->dbpass}" "${CFG->dbname}" > "${BACKUP_DIR}/moodle-database_${CURRENT_DATE}.sql"
    fi
    log_message "Database export completed."
fi

# Create an archive of the Moodle directory
log_message "Starting Moodle directory backup..."
if [ "${VERBOSE}" -eq 1 ]; then
    tar -cvzf "${BACKUP_DIR}/moodle-directory_${CURRENT_DATE}.tar.gz" "${CFG->dirroot}"
else
    tar -czf "${BACKUP_DIR}/moodle-directory_${CURRENT_DATE}.tar.gz" "${CFG->dirroot}"
fi
log_message "Moodle directory backup completed."

# Create an archive of the Moodle data directory
log_message "Starting Moodle data directory backup..."
if [ "${VERBOSE}" -eq 1 ]; then
    tar -cvzf "${BACKUP_DIR}/moodledata-directory_${CURRENT_DATE}.tar.gz" "${CFG->dataroot}"
else
    tar -czf "${BACKUP_DIR}/moodledata-directory_${CURRENT_DATE}.tar.gz" "${CFG->dataroot}"
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
