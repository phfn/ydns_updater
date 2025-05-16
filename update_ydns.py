#!/usr/bin/env python3
import time
import subprocess
import logging
import signal
import sys
import ipaddress
import configargparse

# YDNS API endpoint
YDNS_UPDATE_URL = "https://ydns.io/api/v1/update/"
YDNS_IP_RETRIEVAL_URL = "https://ydns.io/api/v1/ip"

# Set up logging
logger = logging.getLogger("ydns_updater")
log_handler = logging.StreamHandler(sys.stdout)
log_formatter = logging.Formatter(
    "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log_handler.setFormatter(log_formatter)
logger.addHandler(log_handler)


def cleanup(_signal, error):
    logger.warning(f"Got {signal.Signals(_signal).name}. Shutting down...")
    exit(0)


signal.signal(signal.SIGINT, cleanup)
signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGHUP, cleanup)



# --- Configuration setup with configargparse ---
parser = configargparse.ArgumentParser(
    default_config_files=["/etc/ydns_updater.conf", "~/.ydns_updater.conf"],
    description="YDNS Updater Script",
    formatter_class=configargparse.ArgumentDefaultsHelpFormatter,
)
parser.add_argument(
    "--host", required=True, env_var="YDNS_HOST", help="YDNS host to update"
)
parser.add_argument(
    "--user", required=True, env_var="YDNS_USER", help="YDNS username"
)
parser.add_argument(
    "--password", required=True, env_var="YDNS_PASSWORD", help="YDNS password"
)
parser.add_argument(
    "--update-interval",
    type=int,
    default=300,
    env_var="UPDATE_INTERVAL",
    help="Update interval in seconds (default: 300)",
)
parser.add_argument(
    "--debug",
    action="store_true",
    env_var="YDNS_DEBUG",
    help="Enable debug logging (also via YDNS_DEBUG environment variable)",
)

args = parser.parse_args()

# Assign configuration values from parsed arguments
YDNS_HOST = args.host
YDNS_USER = args.user
YDNS_PASSWORD = args.password
UPDATE_INTERVAL = args.update_interval

# Set log level based on debug argument
if args.debug:
    logger.setLevel(logging.DEBUG)
else:
    logger.setLevel(logging.INFO)


class YDNSError(Exception):
    """Base exception for YDNS updater debug"""

    pass


class IPRetrievalError(YDNSError):
    """Exception raised when IP retrieval fails"""

    pass


class DNSUpdateError(YDNSError):
    """Exception raised when DNS update fails"""

    pass


def get_ip(ip_version):
    """Retrieve the current public IP address using curl"""
    logger.debug(
        f"Attempting to retrieve current public IPv{ip_version} address from {YDNS_IP_RETRIEVAL_URL}..."
    )

    curl_cmd = ["curl", f"-{ip_version}", "-s", YDNS_IP_RETRIEVAL_URL]
    try:
        ip_response = subprocess.check_output(
            curl_cmd, universal_newlines=True
        ).strip()
    except subprocess.CalledProcessError as e:
        error_msg = f"Failed to retrieve IPv{ip_version} address. curl command failed with exit code {e.returncode}"
        raise IPRetrievalError(error_msg)

    if not ip_response:
        error_msg = (
            f"Failed to retrieve IPv{ip_version} address. Response was empty."
        )
        raise IPRetrievalError(error_msg)

    try:
        if ip_version == 4:
            ipaddress.IPv4Address(ip_response)
        else:
            ipaddress.IPv6Address(ip_response)
    except ValueError:
        error_msg = f"Retrieved address '{ip_response}' is not a valid IPv{ip_version} address."
        raise IPRetrievalError(error_msg)

    logger.debug(
        f"Current public IPv{ip_version} address detected: {ip_response}"
    )
    return ip_response


def update_dns(ip):
    """Update DNS record with the provided IP address"""
    params = f"host={YDNS_HOST}"
    assert ip
    params = f"{params}&ip={ip}"

    full_update_url = f"{YDNS_UPDATE_URL}?{params}"
    logger.debug(f"Update URL: {full_update_url}")

    auth = f"{YDNS_USER}:{YDNS_PASSWORD}"
    curl_update_cmd = ["curl", "-s", "--user", auth, full_update_url]

    try:
        response_body = subprocess.check_output(
            curl_update_cmd, universal_newlines=True
        ).strip()
        curl_status_cmd = [
            "curl",
            "-s",
            "-o",
            "/dev/null",
            "-w",
            "%{http_code}",
            "--user",
            auth,
            full_update_url,
        ]
        http_response_code = int(
            subprocess.check_output(
                curl_status_cmd, universal_newlines=True
            ).strip()
        )

        logger.debug(f"YDNS API Response Code: {http_response_code}")
        logger.debug(f"YDNS API Response Body: {response_body}")

        if http_response_code == 200:
            if "good" in response_body:
                logger.info(f"Success. Updated.   {ip}")
                return True
            else:
                logger.info(f"Success. No update. {ip}")
                return True
        elif http_response_code == 400:
            error_msg = "Bad request (400). Invalid input parameters. Check your YDNS_HOST, IP, or RECORD_ID."
            raise DNSUpdateError(error_msg)
        elif http_response_code == 401:
            error_msg = "Authentication failed (401). Check your YDNS_USER and YDNS_PASSWORD."
            raise DNSUpdateError(error_msg)
        elif http_response_code == 404:
            error_msg = f"Host not found (404). The host {YDNS_HOST} may not exist in your YDNS account."
            raise DNSUpdateError(error_msg)
        else:
            error_msg = f"YDNS update failed. HTTP Status: {http_response_code}, Body: {response_body}"
            raise DNSUpdateError(error_msg)

    except subprocess.CalledProcessError as e:
        error_msg = f"YDNS update request failed with exit code {e.returncode}"
        raise DNSUpdateError(error_msg)


def main():
    """Main function to run the YDNS updater"""
    logger.info("YDNS Updater Script Started.")
    logger.info(f"Host to update: {YDNS_HOST}")
    logger.info(f"Update interval: {UPDATE_INTERVAL} seconds")
    logger.info("-------------------------------------------")

    while True:
        try:
            # Update IPv4
            try:
                ipv4 = get_ip(4)
                update_dns(ipv4)
            except IPRetrievalError as e:
                logger.warning(f"IPv4 update skipped: {str(e)}")
            except DNSUpdateError as e:
                logger.error(f"IPv4 DNS update failed: {str(e)}")

            # Update IPv6
            try:
                ipv6 = get_ip(6)
                update_dns(ipv6)
            except IPRetrievalError as e:
                logger.warning(f"IPv6 update skipped: {str(e)}")
            except DNSUpdateError as e:
                logger.error(f"IPv6 DNS update failed: {str(e)}")

            logger.info(f"Sleeping for {UPDATE_INTERVAL} seconds...")
            time.sleep(UPDATE_INTERVAL)
            logger.info("")

        except KeyboardInterrupt:
            logger.info("YDNS Updater stopped by user.")
            break
        except SystemExit:
            break
        except Exception as e:
            logger.error(f"Unexpected error occurred: {str(e)}")
            time.sleep(10)
            break


if __name__ == "__main__":
    main()
