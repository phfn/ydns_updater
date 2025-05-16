# YDNS Dynamic DNS Updater Docker Container

This project provides the necessary files to create a Docker container that automatically updates your IP address with the ydns.io dynamic DNS service.


## Usage Standalone

Make sure `curl` and `python` (3) is installed.

Run script:
```sh
python update_ydns.py \
--host your_host.ydns.eu \   # Your full YDNS hostname (e.g., `your_host.ydns.eu`).
--user your_username \       # Your YDNS API username or account email.
--password your_api_secret \ # Your YDNS API password or account password.
--update-interval 300 \      # (Optional): How often (in seconds) the script should attempt to update the IP. Defaults to 300 (5 minutes) if not set or if left empty in the `.env` file.
--debug \                    # (Optional): Verbose output. Defaults to False
```
Alternativly you can use the same environment variables as descripe below in docker usage.


## Usage Docker

###  **Configure Environment Variables:**

Copy `.env.example` to a new file named `.env`:
```sh
cp .env.example .env
```
Edit the `.env` file and fill in your YDNS details:

* `YDNS_HOST`: Your full YDNS hostname (e.g., `your_host.ydns.eu`).
* `YDNS_USER`: Your YDNS API username or account email.
* `YDNS_PASSWORD`: Your YDNS API password or account password.
* `UPDATE_INTERVAL` (Optional): How often (in seconds) the script should attempt to update the IP. Defaults to 300 (5 minutes) if not set or if left empty in the `.env` file.
* `YDNS_DEBUG` (Optional): Verbose output. Defaults to False

### Start the container:

```sh
docker-compose up -d --build
```

### Update IPv6 in Docker

IPv6 in Docker requires tinkering.

First create a network:
```sh
docker network create --ipv6 ip6net
```

Uncomment the ending lines in compose.yml to use ipv6, and therefore also update ipv6 addresses.
 ```
#     networks:
#       - ip6net
#
# networks:
#   ip6net:
#     external: true

 ```
