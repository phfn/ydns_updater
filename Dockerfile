# Use a lightweight base image with curl and bash/sh
FROM alpine/curl:latest

# Set working directory
WORKDIR /app

# Copy the update script into the container
COPY update_ydns.sh .

# Make the script executable
RUN chmod +x update_ydns.sh

# Environment variables that need to be set at runtime
# These are placeholders; actual values will be provided when running the container
ENV YDNS_HOST_VAR=""
ENV YDNS_USER_VAR=""
ENV YDNS_PASSWORD_VAR=""
ENV FORCE_IP_VAR=""
ENV RECORD_ID_VAR=""
ENV UPDATE_INTERVAL_VAR="300"

# Run the script when the container starts
CMD ["./update_ydns.sh"]
