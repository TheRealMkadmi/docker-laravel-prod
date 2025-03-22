#!/bin/bash
# Enhanced logging utility for Docker container
# Prepends process name to all log messages
# Usage: 
# logger.sh [process_name] "message"
# Example: logger.sh NGINX "Server started"

log_with_metadata() {
    local process="$1"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    # Read from stdin if no message provided as argument
    if [ -z "$2" ]; then
        while IFS= read -r line; do
            # Skip empty lines
            if [ -n "$line" ]; then
                echo "$timestamp $line"
            fi
        done
    else
        echo "$timestamp [$process] $2"
    fi
}

# Function to log command execution details
log_command() {
    local process="$1"
    shift 1
    local cmd="$@"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    # Evaluate the command string to expand variables
    local expanded_cmd=$(eval echo "$cmd")
    
    # Log the command with variables expanded
    echo "$timestamp Executing command: $expanded_cmd"
    echo "$timestamp Concrete command: $expanded_cmd"
    
    # Execute the command and capture output
    eval "$cmd" | while IFS= read -r line; do
        if [ -n "$line" ]; then
            echo "$timestamp $line"
        fi
    done
}

# Main function - takes process name and optional message
# If message is not provided, it reads from stdin
if [[ "$1" == "COMMAND" ]]; then
    # Special mode for logging commands
    PROCESS_NAME="$2"
    shift 2
    log_command "$PROCESS_NAME" "$@"
elif [ "$#" -lt 1 ]; then
    echo "Usage: $0 <process_name> [message]" >&2
    echo "   or: $0 COMMAND <process_name> command [args...]" >&2
    exit 1
else
    PROCESS_NAME="$1"
    MESSAGE="$2"
    # If message is provided as argument, log it directly
    if [ -n "$MESSAGE" ]; then
        log_with_metadata "$PROCESS_NAME" "$MESSAGE"
    else
        # Otherwise process stdin
        log_with_metadata "$PROCESS_NAME"
    fi
fi