#!/bin/bash
#
# Copyright (c) 2025 Jules Potvin.
# This script is licensed under the Creative Commons Attribution-NonCommercial 4.0 International License.
# To view a copy of this license, visit http://creativecommons.org/licenses/by-nc/4.0/
# or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
#
# Script to validate phone numbers using IPQualityScore.com

# --- Configuration ---
# Your IPQualityScore API Key
APIKEY="xxxxxxxxxxxxxxxxxxxxxxx"

# Countries to include in the query, comma-separated (e.g., "US,CA")
# This helps IPQualityScore enhance fraud scores.
COUNTRIES="US,CA"

# Spam score threshold: If the fraud_score from IPQualityScore is
# greater than this value, the number will be marked as "SPAM".
# IPQualityScore examples suggest 90 for blocking.
# NOTE: The 'SPAM' variable below will now be set to the 'name' value from the API,
# so this threshold primarily affects the 'SPAMSCORE' variable's implicit meaning.
SPAM_THRESHOLD=90

# Logging configuration
# Set to "true" to enable logging, "false" to disable.
ENABLE_LOGGING="true"
# Path to the log file. Ensure the script has write permissions to this location.
LOG_FILE="/var/log/IPQualityScore.log"

# --- Do not modify below this line ---

# The phone number to be validated (passed as the first argument to the script)
CALLINGNUMBER=$1

# Initialize variables
RESULT=""
SPAMSCORE=0
WHITELIST=0
CALLER_NAME="N/A" # Initialize caller name

# --- Whitelist Check (from your original script) ---
# Add numbers here that should always be considered "OK"
# Provide a comma-separated list of whitelisted numbers
WHITELIST_NUMBERS="5555551212,5555551213"

# Iterate through the comma-separated whitelist numbers
IFS=',' read -ra ADDR <<< "$WHITELIST_NUMBERS"
for i in "${ADDR[@]}"; do
  if [[ "$CALLINGNUMBER" == "$i" ]]
  then
    WHITELIST=1
    break # Exit loop once a match is found
  fi
done

# --- API Call to IPQualityScore ---
if [[ $WHITELIST == 0 ]]
then
  # Construct the API URL
  # The phone number to validate is the CALLINGNUMBER
  API_URL="https://www.ipqualityscore.com/api/json/phone/${APIKEY}/${CALLINGNUMBER}?country=${COUNTRIES}"

  # Make the API request using curl
  # -s: Silent mode (don't show progress meter or error messages)
  # -k: Insecure (allow insecure server connections, useful for some environments, but generally avoid if possible)
  # -X GET: Specify GET request method (though default for this URL)
  # -H "Accept: application/json": Request JSON response
  JSON_RESPONSE=$(curl -s -k -X GET -H "Accept: application/json" "${API_URL}")

  # Check if the curl command was successful
  if [ $? -ne 0 ]; then
    echo "SET VARIABLE SPAMSCORE 0"
    echo "SET VARIABLE NAME \"ERROR: Curl failed\""
    # Log the error if logging is enabled
    if [[ "${ENABLE_LOGGING}" == "true" ]]; then
      echo "$(date +"%Y-%m-%d %H:%M:%S") - ERROR: Curl failed for ${CALLINGNUMBER}" >> "${LOG_FILE}"
    fi
    exit 1
  fi

  # --- Logging the API Response ---
  if [[ "${ENABLE_LOGGING}" == "true" ]]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - API Response for ${CALLINGNUMBER}: ${JSON_RESPONSE}" >> "${LOG_FILE}"
  fi

  # Extract the fraud_score using jq
  # jq is a lightweight and flexible command-line JSON processor.
  # Ensure 'jq' is installed on your system (e.g., sudo apt-get install jq or sudo yum install jq)
  SPAMSCORE=$(echo "${JSON_RESPONSE}" | jq -r '.fraud_score // 0') # Use // 0 to default to 0 if fraud_score is null/missing

  # Extract the 'name' value using jq
  # Defaults to "N/A" if the 'name' field is missing or null
  CALLER_NAME=$(echo "${JSON_RESPONSE}" | jq -r '.name // "N/A"')

  # Check if jq successfully extracted a number for SPAMSCORE
  if ! [[ "$SPAMSCORE" =~ ^[0-9]+$ ]]; then
    SPAMSCORE=0 # Default to 0 if extraction failed or was not a number
  fi
fi

# --- Set SPAM variable to the 'name' value ---
if [[ $WHITELIST == 1 ]]; then
  CALLER_NAME="WHITELISTED" # Explicitly mark whitelisted numbers
fi

# --- Output for FreePBX ---
# These lines are crucial for FreePBX to capture the variables
echo "SET VARIABLE SPAMSCORE ${SPAMSCORE}"
echo "SET VARIABLE NAME \"${CALLER_NAME}\""

exit 0
# eof

# --- Log Rotation for Ubuntu (for /var/log/IPQualityScore.log) ---
# To automatically rotate the log file, create a new file in /etc/logrotate.d/
# For example, create /etc/logrotate.d/ipqualityscore with the following content:
#
# /var/log/IPQualityScore.log {
#     daily
#     missingok
#     rotate 7
#     compress
#     delaycompress
#     notifempty
#     create 0640 asterisk adm
#     sharedscripts
#     postrotate
#         /usr/bin/find /var/log/ -name "IPQualityScore.log-*" -mtime +7 -delete || true
#     endscript
# }
#
# This configuration will:
# - Rotate the log file daily.
# - Not complain if the log file is missing.
# - Keep 7 rotated log files.
# - Compress old log files.
# - Delay compression until the next rotation cycle.
# - Not rotate if the log file is empty.
# - Create a new log file with permissions 0640, owned by user 'asterisk' and group 'adm'.
# - Run the postrotate script after rotation, which cleans up files older than 7 days.
# Remember to adjust user/group if 'asterisk' and 'adm' are not appropriate on your system.
