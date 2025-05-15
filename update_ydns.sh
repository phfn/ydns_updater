#!/bin/sh

# YDNS API endpoint
YDNS_UPDATE_URL="https://ydns.io/api/v1/update/"
YDNS_IP_RETRIEVAL_URL="https://ydns.io/api/v1/ip"

# --- Configuration ---
# Read from environment variables, with defaults if not set for some
YDNS_HOST="${YDNS_HOST_VAR:?Error: YDNS_HOST_VAR environment variable not set.}"
YDNS_USER="${YDNS_USER_VAR:?Error: YDNS_USER_VAR environment variable not set.}"
YDNS_PASSWORD="${YDNS_PASSWORD_VAR:?Error: YDNS_PASSWORD_VAR environment variable not set.}"
# Optional: Override IP detection. Leave empty to auto-detect.
FORCE_IP="${FORCE_IP_VAR:-}"
# Optional: Specify a record ID. Leave empty for auto-detection by host.
RECORD_ID="${RECORD_ID_VAR:-}"
# Update interval in seconds. Default: 300 seconds (5 minutes)
UPDATE_INTERVAL="${UPDATE_INTERVAL_VAR:-300}"

# --- Helper Functions ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# --- Main Logic ---
CURRENT_IP=""
LAST_SUCCESSFUL_IP=""

update_dns() {
    log "Starting YDNS update process for host: ${YDNS_HOST}"

    # 1. Determine IP Address
    if [ -n "${FORCE_IP}" ]; then
        CURRENT_IP="${FORCE_IP}"
        log "Using forced IP address: ${CURRENT_IP}"
    else
        log "Attempting to retrieve current public IP address from ${YDNS_IP_RETRIEVAL_URL}..."
        IP_RESPONSE=$(curl -s "${YDNS_IP_RETRIEVAL_URL}")
        if [ -z "${IP_RESPONSE}" ]; then
            log "Error: Failed to retrieve IP address. Response was empty."
            return 1
        fi
        # Basic check if the response is an IP (simplistic)
        if ! echo "${IP_RESPONSE}" | grep -E -q '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$|^[0-9a-fA-F:]+$'; then
            log "Error: Retrieved IP address '${IP_RESPONSE}' does not look valid."
            return 1
        fi
        CURRENT_IP="${IP_RESPONSE}"
        log "Current public IP address detected: ${CURRENT_IP}"
    fi

    if [ "${CURRENT_IP}" = "${LAST_SUCCESSFUL_IP}" ]; then
        log "IP address (${CURRENT_IP}) has not changed since last successful update. Skipping update."
        return 0
    fi

    # 2. Construct Update URL
    PARAMS="host=${YDNS_HOST}"
    if [ -n "${CURRENT_IP}" ]; then # Always true at this point, but good practice
        PARAMS="${PARAMS}&ip=${CURRENT_IP}"
    fi
    if [ -n "${RECORD_ID}" ]; then
        PARAMS="${PARAMS}&record_id=${RECORD_ID}"
    fi

    FULL_UPDATE_URL="${YDNS_UPDATE_URL}?${PARAMS}"
    log "Update URL: ${FULL_UPDATE_URL}" # Be cautious logging URLs with sensitive data if logs are public

    # 3. Perform Update
    log "Sending update request to YDNS..."
    HTTP_RESPONSE_CODE=$(curl -s -w "%{http_code}" -o /tmp/ydns_update_response.txt --user "${YDNS_USER}:${YDNS_PASSWORD}" "${FULL_UPDATE_URL}")
    RESPONSE_BODY=$(cat /tmp/ydns_update_response.txt)
    rm -f /tmp/ydns_update_response.txt

    log "YDNS API Response Code: ${HTTP_RESPONSE_CODE}"
    log "YDNS API Response Body: ${RESPONSE_BODY}"

    # 4. Check Response
    if [ "${HTTP_RESPONSE_CODE}" -eq 200 ]; then
        log "Successfully updated YDNS IP address for ${YDNS_HOST} to ${CURRENT_IP}."
        LAST_SUCCESSFUL_IP="${CURRENT_IP}"
        return 0
    elif [ "${HTTP_RESPONSE_CODE}" -eq 400 ]; then
        log "Error: Bad request (400). Invalid input parameters. Check your YDNS_HOST, IP, or RECORD_ID."
    elif [ "${HTTP_RESPONSE_CODE}" -eq 401 ]; then
        log "Error: Authentication failed (401). Check your YDNS_USER_VAR and YDNS_PASSWORD_VAR."
    elif [ "${HTTP_RESPONSE_CODE}" -eq 404 ]; then
        log "Error: Host not found (404). The host ${YDNS_HOST} may not exist in your YDNS account."
    else
        log "Error: YDNS update failed. HTTP Status: ${HTTP_RESPONSE_CODE}, Body: ${RESPONSE_BODY}"
    fi
    return 1
}

# --- Main Loop ---
log "YDNS Updater Script Started."
log "Host to update: ${YDNS_HOST}"
log "Update interval: ${UPDATE_INTERVAL} seconds"
if [ -n "${FORCE_IP}" ]; then log "Forcing IP to: ${FORCE_IP}"; fi
if [ -n "${RECORD_ID}" ]; then log "Using Record ID: ${RECORD_ID}"; fi

while true; do
    update_dns
    log "Sleeping for ${UPDATE_INTERVAL} seconds..."
    sleep "${UPDATE_INTERVAL}"
done
