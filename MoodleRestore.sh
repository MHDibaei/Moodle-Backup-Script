#!/bin/bash

# Check for verbose flag
VERBOSE=0
if [ "$1" == "-v" ] || [ "$1" == "--verbose" ]; then
    VERBOSE=1
fi

if [ -z "$1" ]; then
    echo "No please provide the backup folder as an argument."
    exit 1
fi

MOODLE_ROOT_DIR="/var/www/"

# Define the log file
LOG_FILE="${MOODLE_ROOT_DIR}/MoodleRestoreLogs.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "${LOG_FILE}"
}


# Define the variables
SERVICES=("mariadb" "mysql" "nginx" "apache2")
BACKUP_DIR="$1"

MOODLE_DIR=$(ls -Art "$1"/moodle_*.tar.gz | tail -n 1)
MOODLE_DATA_DIR=$(ls -Art "$1"/moodledata_*.tar.gz | tail -n 1)
MOODLE_DATABASE=$(ls -Art "$1"/moodle-database_*.sql | tail -n 1)



# Loop through the services
for service in "${SERVICES[@]}"; do
    
    # Check if the service is active
    if systemctl is-active --quiet $service; then
        case $service in
            "apache2"|"nginx")
                log_message "$service is installed and running."
                log_message "Extracting Moodle directory..."
                if [ "${VERBOSE}" -eq 1 ]; then
                    tar -xvzf $MOODLE_DIR -C $MOODLE_ROOT_DIR
                    tar -xvzf $MOODLE_DATA_DIR -C $MOODLE_ROOT_DIR
                else
                    tar -xzf $MOODLE_DIR -C $MOODLE_ROOT_DIR
                    tar -xzf $MOODLE_DATA_DIR -C $MOODLE_ROOT_DIR
                fi
                log_message "Restoring Moodle directories finished."
            ;;
            "mysql"|"mariadb")
                log_message "$service is installed and running. This is a database service."
                log_message "Restoreing databse..."
                
                DBUSER=$(cat $MOODLE_ROOT_DIR/moodle/config.php | grep "\$CFG->dbuser" | cut -d "'" -f 2)
                DBPASS=$(cat $MOODLE_ROOT_DIR/moodle/config.php | grep "\$CFG->dbpass" | cut -d "'" -f 2)
                DBNAME=$(cat $MOODLE_ROOT_DIR/moodle/config.php | grep "\$CFG->dbname" | cut -d "'" -f 2)
                
                MOODLE_DATABASE_EXISTS=$(mysql -u "$2" -p"$3" -e "SHOW DATABASES;" | grep -c "$DBNAME")
                MOODLE_DATABASE_USER_EXISTS=$(mysql -u "$2" -p"$3" -e "SELECT User FROM mysql.user;" | grep -c "$DBUSER")
                
                if [ $MOODLE_DATABASE_USER_EXISTS -eq 0 ]; then
                    mysql -u "$2" -p"$3" -e "CREATE USER $DBUSER@localhost IDENTIFIED BY '$DBPASS'; GRANT ALL PRIVILEGES ON *.* TO $DBUSER@localhost;"
                else
                    if [ $MOODLE_DATABASE_EXISTS -eq 0 ]; then
                        mysql -u "$2" -p"$3" -e "CREATE DATABASE $DBNAME;"
                    else
                        if [ "${VERBOSE}" -eq 1 ]; then
                            mysql -v -u "$DBPASS" -p"$DBPASS" $DBNAME < $MOODLE_DATABASE
                        else
                            mysql -u "$DBPASS" -p"$DBPASS" $DBNAME < $MOODLE_DATABASE
                        fi
                    fi
                    
                    # If the database user or database doesn't exist, restart the script
                    if [ $MOODLE_DATABASE_USER_EXISTS -eq 0 ] || [ $MOODLE_DATABASE_EXISTS -eq 0 ]; then
                        $0
                    fi
                fi
                
            ;;
            *)
                log_message "$service is not recognized."
                exit 1;
            ;;
        esac
    else
        log_message "$service is not running or not installed."
        exit 1;
    fi
    
done