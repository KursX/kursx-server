# ktor-server
Fast deploying server for Android developers on Ktor with files, resources and database

All you need to do is:
- Rent a real or virtual server (VPS) with Ubuntu 24.04 LTS
- Buy a domain name from any domain name provider
- Register the IP address of your server in the DNS settings of the purchased domain
- Sign in to your paid server via ssh
- Run the first command to download the server code
- Run the second command to install and configure everything necessary for the server work


```
ssh root@DOMAIN
```
```
sudo apt update && sudo apt install -y git && git clone https://github.com/KursX/kursx-server.git /opt/kursx-server
```

```
bash /opt/kursx-server/install.sh IP DOMAIN TOMCAT_VERSION
```
Example:
```
bash /opt/kursx-server/install.sh 192.168.0.0 example.com 10.1.34
```
Actual [TOMCAT_VERSION](https://downloads.apache.org/tomcat/tomcat-10/)

To apply code changes and restart server:

```
./gradlew war
```