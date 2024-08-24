#!/bin/bash

# Function to install the Cali Web Design Panel
function install_caliwebpanel() {
    # Install and configure MariaDB
    if [ ! -x "$(command -v mysql)" ]; then
        sudo apt update
        sudo apt install -y mariadb-server

        # Secure MariaDB installation
        sudo mysql_secure_installation
    else
        echo "MariaDB is already installed."
    fi

    # Install Docker and Set Docker up.

    if [ ! -x "$(command -v docker)" ]; then
        sudo apt-get update
        sudo apt-get install ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        echo "Docker is already installed."
    fi

    # Install the latest version of PHP and PHP-FPM
    if [ ! -x "$(command -v php)" ] || [ ! -x "$(command -v php-fpm)" ]; then
        sudo apt update
        sudo apt install -y php php-fpm

        # Install common PHP extensions
        sudo apt install -y php-mysql php-curl php-gd php-json php-mbstring php-xml php-zip

        # Restart PHP-FPM
        sudo systemctl restart php-fpm
    else
        echo "PHP and PHP-FPM are already installed."
    fi

    # Check if Nginx is installed
    if [ ! -x "$(command -v nginx)" ]; then
        # Install Nginx
        sudo apt update
        sudo apt install -y nginx
    else
        echo "Nginx is already installed."
    fi

    # Prompt the user for the directory to store web files
    read -p "Enter the directory path to store web files (e.g., /var/www/html): " web_directory

    # Create directory for website
    sudo mkdir -p $web_directory

    # Set permissions
    sudo chown -R $USER:$USER $web_directory
    sudo chmod -R 755 $web_directory

    # Create a sample index.php file
    echo "<?php
    phpinfo();
    ?>" | sudo tee $web_directory/index.php

    # Create Nginx default HTTP configuration file
    sudo cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root $web_directory;
    index index.php index.html index.htm;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock; # Change to your PHP version
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

    # Enable the default site by creating a symbolic link
    sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/

    # Test Nginx configuration
    sudo nginx -t

    # Reload Nginx to apply changes
    sudo systemctl reload nginx

    # Ask the user for the domain name
    read -p "Enter your domain name: " domain_name

    # Obtain SSL certificate for the domain using Certbot
    sudo certbot --nginx -d $domain_name

    # Modify Nginx configuration to use SSL and PHP for the domain
    sudo cat <<EOF > /etc/nginx/sites-available/$domain_name
server {
    listen 80;
    listen [::]:80;

    server_name $domain_name www.$domain_name;

    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name $domain_name www.$domain_name;

    ssl_certificate /etc/letsencrypt/live/$domain_name/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain_name/privkey.pem;

    root $web_directory;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock; # Change to your PHP version
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

    # Enable the site by creating a symbolic link
    sudo ln -s /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/

    # Remove default Nginx configuration
    sudo rm /etc/nginx/sites-enabled/default

    # Test Nginx configuration
    sudo nginx -t

    # Reload Nginx to apply changes
    sudo systemctl reload nginx

    # Display success message
    echo "Cali Web Design Panel installed and configured for $domain_name."
    echo "To access your panel please visit https://$domain_name"
}

# Function to uninstall the Cali Web Design Panel
function uninstall_caliwebpanel() {
    # Uninstall Nginx
    if [ -x "$(command -v nginx)" ]; then
        # Stop and disable Nginx service
        sudo systemctl stop nginx
        sudo systemctl disable nginx

        # Remove Nginx packages
        sudo apt purge -y nginx nginx-common nginx-full
        sudo apt purge -y certbot python3-certbot-nginx
        sudo apt autoremove -y

        # Remove Nginx directories
        sudo rm -rf /etc/nginx

        echo "Nginx and related packages have been uninstalled."
    else
        echo "Nginx is not installed."
    fi

    # Uninstall MariaDB
    if [ -x "$(command -v mysql)" ]; then
        # Stop and disable MariaDB service
        sudo systemctl stop mariadb
        sudo systemctl disable mariadb

        # Remove MariaDB packages
        sudo apt purge -y mariadb-server mariadb-client mariadb-common
        sudo apt autoremove -y

        # Remove MariaDB directories and data
        sudo rm -rf /etc/mysql /var/lib/mysql /var/log/mysql

        echo "MariaDB and related packages have been uninstalled."
    else
        echo "MariaDB is not installed."
    fi

    # Remove Composer
    if [ -x "$(command -v composer)" ]; then
        sudo rm -rf /usr/local/bin/composer
        echo "Composer has been uninstalled."
    else
        echo "Composer is not installed."
    fi

    # Display success message
    echo "The Cali Web Design Panel has been completely uninstalled."
}

# Main script starts here
echo "Welcome to Cali Web Design Panel Installation/Removal"
echo "-----------------------------------------------------"
echo "1. Install Cali Web Design Panel"
echo "2. Uninstall Cali Web Design Panel"
echo "-----------------------------------------------------"
read -p "Enter your choice (1 or 2): " choice

case $choice in
    1) install_caliwebpanel ;;
    2) uninstall_caliwebpanel ;;
    *) echo "Invalid choice. Please enter either 1 or 2." ;;
esac
