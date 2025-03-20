#!/bin/bash
# Enhanced logging utility for Docker container
# Prepends process name and log level to all log messages

# Usage: 
# logger.sh [process_name] [log_level] "message"
# Example: logger.sh NGINX INFO "Server started"

log_with_metadata() {
    local process="$1"
    local level="$2"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    # Read from stdin if no message provided as argument
    if [ -z "$3" ]; then
        while IFS= read -r line; do
            # Skip empty lines
            if [ -n "$line" ]; then
                echo "$timestamp [$process] [$level] $line"
            fi
        done
    else
        echo "$timestamp [$process] [$level] $3"
    fi
}

# Main function - takes process name, level and optional message
# If message is not provided, it reads from stdin
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <process_name> <log_level> [message]" >&2
    exit 1
fi

PROCESS_NAME="$1"
LOG_LEVEL="$2"
MESSAGE="$3"

# If message is provided as argument, log it directly
if [ -n "$MESSAGE" ]; then
    log_with_metadata "$PROCESS_NAME" "$LOG_LEVEL" "$MESSAGE"
else
    # Otherwise process stdin
    log_with_metadata "$PROCESS_NAME" "$LOG_LEVEL"
fi