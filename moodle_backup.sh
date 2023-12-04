#!/usr/bin/env bash

# Set the color variable
green='\033[0;32m'
red='\033[0;31m'
yellow='\033[0;33m'
# Clear the color after that
clear='\033[0m'

DATE=$(date +%Y%m%d)

# Set default verbose mode to false and enable it if the second argument is --verbose
VERBOSE=false
if [ $# -eq 2 ] && [ "$2" == "--verbose" ]; then
  VERBOSE=true
fi

# Check if Site DIR is specified as 1st argument
if [ -z "$1" ]
then
 echo -e "${yellow}Provide path to site as argument: /var/www/moodle${clear}"
 exit 1
fi
# Strip trailing slashes from SITE_DIR
SITE_DIR=${1%/}

# Check if backup directory exists
BACKUP_DIR="${SITE_DIR%/*}/backup_${SITE_DIR##*/}"

if [ ! -d "${BACKUP_DIR}" ] && [ "$(mkdir -p ${BACKUP_DIR})" ]; then
    echo "Directory not found. The script can't create it, either!"
    echo "Please create it manually and then re-run this script"
    exit 1
fi

# Turn on logging of this script into log file, located in user's HOME dir


LOG_FILE=${BACKUP_DIR}/backup_${DATE}.log
exec > >(tee -a ${LOG_FILE} )
exec 2> >(tee -a ${LOG_FILE} >&2)

# Get auto site DB ans moodledata configs here (for MOODLE)
DB_TYPE=`cat ${SITE_DIR}/config.php | grep dbtype | cut -d \' -f 2`
DB_NAME=`cat ${SITE_DIR}/config.php | grep dbname | cut -d \' -f 2`
DB_USER=`cat ${SITE_DIR}/config.php | grep dbuser| cut -d \' -f 2`
DB_PASSWORD=`cat ${SITE_DIR}/config.php | grep dbpass | cut -d \' -f 2`
DB_HOST=`cat ${SITE_DIR}/config.php | grep dbhost | cut -d \' -f 2`
MDATA=`cat ${SITE_DIR}/config.php | grep dataroot | cut -d \' -f 2`

# Make DB dump in SITE_DIR
echo -n "Dumping database... "
if [ $DB_TYPE == "mariadb" ]; then
    echo "of the mariadb type..."
    DUMP_NAME="${DB_NAME}"_"${DATE}".sql
    DUMP_ADDRESS="${BACKUP_DIR}/${DUMP_NAME}"
    mariadb-dump --user=${DB_USER} --password=${DB_PASSWORD} --host=${DB_HOST} --databases ${DB_NAME} > $DUMP_ADDRESS
    if [ "$?" -ne "0" ]; then
            echo -e "${red}failed!${clear}"
            exit 1
    fi
    echo -e "${green}DB backup has finished. you can find it in ${DUMP_ADDRESS}${clear}"
fi

# Create the backup file name
BACKUP_FILE="${BACKUP_DIR}/${DATE}.tar.gz"

# Create the backup archive
echo -n "Creating moodle archive... "
if $VERBOSE; then
  tar -czfv $BACKUP_FILE $SITE_DIR $MDATA
else
  tar -czf $BACKUP_FILE $SITE_DIR $MDATA
fi

# Check the exit status of the tar command
if [ $? -ne 0 ]; then
  echo -e "${red}failed!${clear}"
  exit 1
fi

echo -e "${green}Moodle files backup has finished. you can find it in ${BACKUP_FILE}${clear}"