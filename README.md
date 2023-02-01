# magento2docker
This setup is designed to quickly demo Magento 2 or serve as a development environment.
The main Docker image, osioaliu/magento2docker, includes all necessary applications 
(Nginx, PHP, MariaDB, Redis, Elasticsearch) to run Magento 2.

> This setup should not be used on a production server due to security concerns.

## Magento 2 Demo
### 1. Run the following command to start the container:

    docker run --rm -dt --name magento2docker osioaliu/magento2docker

### 2. Execute the following command to get Magento 2 IP:

    docker exec -t magento2docker start


## Magento 2 Dev
If you want to use this setup with your own project, you can use the `docker-compose.yml file. 
This file includes additional containers with Mailhog, Watchtower, and Rabbitmq 
which you may find useful for your project. These containers are currently commented out.

    git clone https://github.com/aliuosio/magento2docker.git
    cd magento2docker
    chmod +x bin/dev
    bin/dev

Only the `app/code`, `dev`, `composer.json` foldera are mapped as a volumes due perfomance.
The rest of the magento files are copied to a folder parralel to htdocs so you can add it as a library to your IDE

> The image with the `dev` tag used in the `docker-compose.yml` has xdebug installed with magento2docker as the idekey.

## Accessing the Application
### Backend

    URL: http://<ip displayed on your console>/admin
    Username: mage2_admin
    Password: mage2_admin123#T

### Frontend
    
    URL: http://<ip displayed on your console>

### Additional Composer Packages
**magento2-gmailsmtpapp**

Configures Magento 2 / Adobe Commerce to send transactional emails using Google App, Gmail, Amazon Simple Email Service (SES), Microsoft Office365 or any other SMTP servers.


**Yireo/magento2-webp2**

Adds WebP support to Magento 2.
dominicwatts/cachewarmer: Magento 2 Site based Cachewarmer / Link checker / Siege Tester and should not be used in production environments.
