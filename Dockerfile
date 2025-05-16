# Use official Python Alpine image for small size
FROM python:3-alpine

# Install required system dependencies
RUN apk add --no-cache curl

# Install Python dependencies
RUN pip install --no-cache-dir configargparse

# Create app directory and non-root user
RUN adduser -D ydnsuser
WORKDIR /app
COPY update_ydns.py /app/

# Set ownership and switch to non-root user
RUN chown ydnsuser:ydnsuser /app/update_ydns.py
USER ydnsuser

# Set default environment variables
ENV UPDATE_INTERVAL=300

# Document expected environment variables
ENV YDNS_HOST="" \
    YDNS_USER="" \
    YDNS_PASSWORD=""

# Health check to verify script is running
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s \
    CMD pgrep -f update_ydns.py || exit 1

# Run the updater
ENTRYPOINT ["python3", "update_ydns.py"]
