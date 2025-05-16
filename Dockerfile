# Use a lightweight base image with curl and bash/sh
FROM alpine/curl:latest

# Set working directory
WORKDIR /app

# Copy the update script into the container
COPY update_ydns.sh .

# Make the script executable
RUN chmod +x update_ydns.sh

# Run the script when the container starts
CMD ["./update_ydns.sh"]
