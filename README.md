# YDNS Dynamic DNS Updater Docker Container

This project provides the necessary files to create a Docker container that automatically updates your IP address with the ydns.io dynamic DNS service.

## AI Warning

This code is mainly written by AI. It seems to work, but you should review if you want to use it.

## Not working

IPv6 in Docker requires tinkering.

## Files

* `update_ydns.sh`: The core shell script that interacts with the YDNS API.
* `Dockerfile`: Defines the Docker image.
* `docker-compose.yml`: For easy building and running of the container.
* `.env.example`: Template for environment variables.
* `README.md`: This file.

## Prerequisites

* Docker installed
* Docker Compose installed (recommended)
* A YDNS account and a hostname configured.
* Your YDNS API username and password (or account credentials).

## Setup and Usage

1.  **Clone or Download Files:**
    Ensure all the files (`update_ydns.sh`, `Dockerfile`, `docker-compose.yml`, `.env.example`) are in the same directory.

2.  **Configure Environment Variables:**
    Copy `.env.example` to a new file named `.env`:
    ```sh
    cp .env.example .env
    ```
    Edit the `.env` file and fill in your YDNS details:
    * `YDNS_HOST_VAR`: Your full YDNS hostname (e.g., `mycomputer.ydns.io`).
    * `YDNS_USER_VAR`: Your YDNS API username or account email.
    * `YDNS_PASSWORD_VAR`: Your YDNS API password or account password.
    * `FORCE_IP_VAR` (Optional): If you want to set a specific IP address. Leave empty to auto-detect your public IP.
    * `RECORD_ID_VAR` (Optional): If you need to update a specific record ID for your host. Leave empty if unsure.
    * `UPDATE_INTERVAL_VAR` (Optional): How often (in seconds) the script should attempt to update the IP. Defaults to 300 (5 minutes) if not set or if left empty in the `.env` file.

    **Important:** If you are not using the `env_file` directive in `docker-compose.yml`, you will need to ensure these environment variables are set in your shell before running `docker-compose up`, or pass them directly on the command line. For `docker-compose.yml` as provided, it will expect these variables to be set in the environment it is run from, or you can uncomment the `env_file: .env` section.

3.  **Build and Run with Docker Compose (Recommended):**

    * **To use the `.env` file directly with `docker-compose`:**
        Uncomment the following lines in `docker-compose.yml`:
        ```yaml
        # env_file:
        #   - .env
        ```
        becomes:
        ```yaml
        env_file:
          - .env
        ```

    * **Start the container:**
        ```sh
        docker-compose up -d --build
        ```
        * `-d`: Runs the container in detached mode (in the background).
        * `--build`: Forces Docker Compose to build the image before starting.

4.  **Build and Run with Docker (Manual):**
    If you prefer not to use Docker Compose:

    * **Build the Docker image:**
        ```sh
        docker build -t ydns-updater .
        ```
    * **Run the Docker container:**
        You need to pass the environment variables directly.
        ```sh
        docker run -d --name ydns-updater \
          --restart unless-stopped \
          -e YDNS_HOST_VAR="your-hostname.ydns.io" \
          -e YDNS_USER_VAR="your_api_username_or_email" \
          -e YDNS_PASSWORD_VAR="your_api_password" \
          -e FORCE_IP_VAR="" \
          -e RECORD_ID_VAR="" \
          -e UPDATE_INTERVAL_VAR="300" \
          ydns-updater
        ```
        Replace the placeholder values with your actual credentials and settings.

## Managing the Container

* **Check Logs:**
    * With Docker Compose: `docker-compose logs -f ydns-updater`
    * With Docker: `docker logs -f ydns-updater`

* **Stop the Container:**
    * With Docker Compose: `docker-compose down`
    * With Docker: `docker stop ydns-updater`

* **Remove the Container (if stopped):**
    * With Docker Compose (also removes network if created): `docker-compose down`
    * With Docker: `docker rm ydns-updater`

* **Remove the Image:**
    ```sh
    docker rmi ydns-updater
    ```

## Security Note

Your YDNS credentials are stored as environment variables within the Docker container. Ensure your Docker host environment is secure. Do not commit your `.env` file with actual credentials to public version control systems.
