## magento2docker

This Setup can be used to fast demo magento 2 or as as development enviroment.
The main docker image `osioaliu/magento2docker` has all applications (Nginx, PHP, MariaDB, Redis, Elasticsearch) needed to run Magento 2
> Do not use due to security on a production server

### Start 

    docker run --rm -dt --name magento2docker osioaliu/magento2docker
    docker exec -t magento2docker start

> next time just start the server with command: magento2docker 

### or start in `docker-compose.yml` to use with own project
  this has additinal cotainers with Mailhog, Watchtower and rabbitmq which you might need in your project commented out
  Download `https://raw.githubusercontent.com/aliuosio/magento2docker/main/docker-compose.yml`
  
    docker-compose up -d                # to start all containers
    docker compose exec -it main start  # to install Magento 2
    docker compose exec -it main xdebug # to use xdebug with ide.key magento2docker

#### Backend
    http://<ip displayed on your console>/admin
    User: mage2_admin
    Password: mage2_admin123#T

#### Frontend
    http://<ip displayed on your console>

##### Extra Composer Packages installed:
* **magento2-gmailsmtpapp**
   
  configure Magento 2 / Adobe Commerce to send all transactional emails using Google App, Gmail, Amazon Simple Email Service (SES), Microsoft Office365 or any other SMTP servers.


* **yireo/magento2-webp2**

    This module adds WebP support to Magento 2.


* **dominicwatts/cachewarmer**

  Magento 2 Site based Cachewarmer / Link checker / Siege Tester

> Never use in Production, It's meant to demo or as dev enviroment

**Todos:**

V1
* ~~create db before magento install~~
* ~~set webp executable and make sure magento uses it~~
* ~~add redis~~
* ~~reduce docker image size~~
* ~~Use php alpine image as base image~~

V2
* make configurable app versions
