#!/bin/sh

# YDNS API endpoint
YDNS_UPDATE_URL="https://ydns.io/api/v1/update/"
YDNS_IP_RETRIEVAL_URL="https://ydns.io/api/v1/ip"

# --- Configuration ---
# Read from environment variables, with defaults if not set for some
YDNS_HOST="${YDNS_HOST:?Error: YDNS_HOST environment variable not set.}"
YDNS_USER="${YDNS_USER:?Error: YDNS_USER environment variable not set.}"
YDNS_PASSWORD="${YDNS_PASSWORD:?Error: YDNS_PASSWORD environment variable not set.}"
# Optional: Override IP detection. Leave empty to auto-detect.
# Update interval in seconds. Default: 300 seconds (5 minutes)
UPDATE_INTERVAL="${UPDATE_INTERVAL:-300}"
YDNS_DEBUG="${YDNS_DEBUG:-""}"
# --- Helper Functions ---
debug() {
	if [ -n "$YDNS_DEBUG" ]; then
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
	fi
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# --- Main Logic ---
CURRENT_IP=""
RETURN=""

get_ip() {
	local ip_version=$1
	debug "Attempting to retrieve current public IPv4 address from ${YDNS_IP_RETRIEVAL_URL}..."
	IP_RESPONSE=$(curl -${ip_version} -s "${YDNS_IP_RETRIEVAL_URL}")
	if [ -z "${IP_RESPONSE}" ]; then
		log "Error (IPv${ip_version}): Failed to retrieve IP address. Response was empty."
		return 1
	fi
	# Basic check if the response is an IP (simplistic)
	if ! echo "${IP_RESPONSE}" | grep -E -q '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$|^[0-9a-fA-F:]+$'; then
		log "Error (IPv${ip_version}): Retrieved IP address '${IP_RESPONSE}' does not look valid."
		return 1
	fi
	CURRENT_IP="${IP_RESPONSE}"
	debug "Current public IPv4 address detected: ${CURRENT_IP}"
	RETURN=$CURRENT_IP
}

update_dns() {
	local ip=$1

    # 2. Construct Update URL
    PARAMS="host=${YDNS_HOST}"
    if [ -n "${CURRENT_IP}" ]; then # Always true at this point, but good practice
        PARAMS="${PARAMS}&ip=${CURRENT_IP}"
    fi

    FULL_UPDATE_URL="${YDNS_UPDATE_URL}?${PARAMS}"
    debug "Update URL: ${FULL_UPDATE_URL}" # Be cautious logging URLs with sensitive data if logs are public

    # 3. Perform Update
    debug "Sending update request to YDNS..."
    HTTP_RESPONSE_CODE=$(curl -s -w "%{http_code}" -o /tmp/ydns_update_response.txt --user "${YDNS_USER}:${YDNS_PASSWORD}" "${FULL_UPDATE_URL}")
    RESPONSE_BODY=$(cat /tmp/ydns_update_response.txt)
    rm -f /tmp/ydns_update_response.txt

    debug "YDNS API Response Code: ${HTTP_RESPONSE_CODE}"
    debug "YDNS API Response Body: ${RESPONSE_BODY}"

    # 4. Check Response
    if [ "${HTTP_RESPONSE_CODE}" -eq 200 ]; then
		if [[ "${RESPONSE_BODY}" =~ "good"  ]]; then
			log "Success. Updated.   ${CURRENT_IP}"
			return 0
		else
			log "Success. No update. ${CURRENT_IP}"
		fi
    elif [ "${HTTP_RESPONSE_CODE}" -eq 400 ]; then
        log "Error: Bad request (400). Invalid input parameters. Check your YDNS_HOST, IP, or RECORD_ID."
    elif [ "${HTTP_RESPONSE_CODE}" -eq 401 ]; then
        log "Error: Authentication failed (401). Check your YDNS_USER and YDNS_PASSWORD."
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
log "-------------------------------------------"

main(){
	while true; do
		get_ip 4
		if [[ "${?}" -eq 0 ]]; then
			local ipv4=$RETURN
			update_dns "${ipv4}"
		fi

		get_ip 6
		if [[ "${?}" -eq 0 ]]; then
			local ipv6=$RETURN
			update_dns "${ipv6}"
		fi

		log "Sleeping for ${UPDATE_INTERVAL} seconds..."
		sleep "${UPDATE_INTERVAL}"
		log
	done
}
main

