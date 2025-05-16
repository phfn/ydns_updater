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
RETURN=""

get_ip() {
	local ip_version=$1
	debug "Attempting to retrieve current public IPv4 address from ${YDNS_IP_RETRIEVAL_URL}..."
	local ip_response=$(curl -${ip_version} -s "${YDNS_IP_RETRIEVAL_URL}")
	if [ -z "${ip_response}" ]; then
		log "Error (IPv${ip_version}): Failed to retrieve IP address. Response was empty."
		return 1
	fi
	# Basic check if the response is an IP (simplistic)
	if ! echo "${ip_response}" | grep -E -q '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$|^[0-9a-fA-F:]+$'; then
		log "Error (IPv${ip_version}): Retrieved IP address '${ip_response}' does not look valid."
		return 1
	fi
	debug "Current public IPv4 address detected: ${ip_response}"
	RETURN=$ip_response
}

update_dns() {
	local ip=$1

    # 2. Construct Update URL
    local params="host=${YDNS_HOST}"
    if [ -n "${ip}" ]; then # Always true at this point, but good practice
        params="${params}&ip=${ip}"
    fi

    local full_update_url="${YDNS_UPDATE_URL}?${params}"
    debug "Update URL: ${full_update_url}" # Be cautious logging URLs with sensitive data if logs are public

    # 3. Perform Update
    debug "Sending update request to YDNS..."
    local http_response_code=$(curl -s -w "%{http_code}" -o /tmp/ydns_update_response.txt --user "${YDNS_USER}:${YDNS_PASSWORD}" "${full_update_url}")
    local response_body=$(cat /tmp/ydns_update_response.txt)
    rm -f /tmp/ydns_update_response.txt

    debug "YDNS API Response Code: ${http_response_code}"
    debug "YDNS API Response Body: ${response_body}"

    # 4. Check Response
    if [ "${http_response_code}" -eq 200 ]; then
		if [[ "${response_body}" =~ "good"  ]]; then
			log "Success. Updated.   ${ip}"
			return 0
		else
			log "Success. No update. ${ip}"
		fi
    elif [ "${http_response_code}" -eq 400 ]; then
        log "Error: Bad request (400). Invalid input parameters. Check your YDNS_HOST, IP, or RECORD_ID."
    elif [ "${http_response_code}" -eq 401 ]; then
        log "Error: Authentication failed (401). Check your YDNS_USER and YDNS_PASSWORD."
    elif [ "${http_response_code}" -eq 404 ]; then
        log "Error: Host not found (404). The host ${YDNS_HOST} may not exist in your YDNS account."
    else
        log "Error: YDNS update failed. HTTP Status: ${http_response_code}, Body: ${response_body}"
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

