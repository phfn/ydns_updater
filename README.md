# YDNS Dynamic DNS Updater Docker Container

This project provides the necessary files to create a Docker container that automatically updates your IP address with the ydns.io dynamic DNS service.


## Usage Standalone

Make sure `curl` is installed.

Set enviroment variables
```sh
export YDNS_HOST="" # Your full YDNS hostname (e.g., `mycomputer.ydns.io`).
export YDNS_USER="" # Your YDNS API username or account email.
export YDNS_PASSWORD="" # Your YDNS API password or account password.
export UPDATE_INTERVAL="" # Optional: How often (in seconds) the script should attempt to update the IP. Defaults to 300 (5 minutes).
export YDNS_DEBUG="" # Optional: Set to any value to enable more output
```
Or [use .env file](https://stackoverflow.com/questions/43267413/how-to-set-environment-variables-from-env-file):
```sh
set -a # automatically export all variables
source .env
set +a
```
Run script:
```sh
./update_ydns.sh
```


## Usage Docker

###  **Configure Environment Variables:**

Copy `.env.example` to a new file named `.env`:
```sh
cp .env.example .env
```
Edit the `.env` file and fill in your YDNS details:

* `YDNS_HOST`: Your full YDNS hostname (e.g., `mycomputer.ydns.io`).
* `YDNS_USER`: Your YDNS API username or account email.
* `YDNS_PASSWORD`: Your YDNS API password or account password.
* `UPDATE_INTERVAL` (Optional): How often (in seconds) the script should attempt to update the IP. Defaults to 300 (5 minutes) if not set or if left empty in the `.env` file.

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

