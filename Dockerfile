FROM debian:bookworm-slim

# Prevent interactive prompts during apt installations
ENV DEBIAN_FRONTEND=noninteractive

# Install Smokeping, Apache2, and script dependencies
RUN apt-get update && apt-get install -y \
    smokeping \
    apache2 \
    curl \
    jq \
    iputils-ping \
    fping \
    && rm -rf /var/lib/apt/lists/*

# Enable Apache2 CGI module for the Smokeping web UI
RUN a2enmod cgi \
    && ln -s /etc/smokeping/apache2.conf /etc/apache2/conf-available/smokeping.conf \
    && a2enconf smokeping

# Fix permissions for Smokeping directories
RUN mkdir -p /var/run/smokeping /var/lib/smokeping /var/cache/smokeping \
    && chown -R smokeping:www-data /var/lib/smokeping /var/cache/smokeping \
    && chown -R smokeping:www-data /etc/smokeping

# Telegram alert script and make it executable
COPY smokeping-telegram-alert.sh /usr/local/bin/smokeping-telegram-alert.sh
RUN chmod +x /usr/local/bin/smokeping-telegram-alert.sh

# Copy the startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose the Apache web port
EXPOSE 80

# Launch both Smokeping and Apache2
CMD ["/start.sh"]
