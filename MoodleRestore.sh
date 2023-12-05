#!/bin/bash

# Check for verbose flag
VERBOSE=0
if [ "$1" == "-v" ] || [ "$1" == "--verbose" ]; then
    VERBOSE=1
fi

# Define the services
services=("mariadb" "mysql" "nginx" "apache2")

# Loop through the services
for service in "${services[@]}"; do
    # Check if the service is active
    if systemctl is-active --quiet $service; then
        case $service in
            "mysql")
                echo "$service is installed and running. This is a database service."
                ;;
            "mariadb")
                echo "$service is installed and running. This is a database service."
                ;;
            "apache2")
                echo "$service is installed and running. This is a web server service."
                ;;
            "nginx")
                echo "$service is installed and running. This is a web server service."
                ;;
            *)
                echo "$service is not recognized."
                ;;
        esac
        ./run_script.sh
    else
        echo "$service is not running or not installed."
    fi
done