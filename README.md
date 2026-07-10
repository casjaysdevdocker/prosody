## 👋 Welcome to prosody 🚀  

prosody README  
  
  
## Install my system scripts  

```shell
 sudo bash -c "$(curl -q -LSsf "https://github.com/systemmgr/installer/raw/main/install.sh")"
 sudo systemmgr --config && sudo systemmgr install scripts  
```
  
## Automatic install/update  
  
```shell
dockermgr update prosody
```
  
## Install and run container
  
```shell
dockerHome="/srv/$USER/docker/casjaysdevdocker/prosody/prosody/latest/volumes"
mkdir -p "/srv/$USER/docker/prosody/volumes"
git clone "https://github.com/dockermgr/prosody" "$HOME/.local/share/CasjaysDev/dockermgr/prosody"
cp -Rfva "$HOME/.local/share/CasjaysDev/dockermgr/prosody/volumes/." "$dockerHome/"
docker run -d \
--restart always \
--privileged \
--name casjaysdevdocker-prosody-latest \
--hostname prosody \
-e TZ=${TIMEZONE:-America/New_York} \
-v "$dockerHome/data:/data:z" \
-v "$dockerHome/config:/config:z" \
-p 80:80 \
casjaysdevdocker/prosody:latest
```
  
## via docker-compose  
  
```yaml
version: "2"
services:
  ProjectName:
    image: casjaysdevdocker/prosody
    container_name: casjaysdevdocker-prosody
    environment:
      - TZ=America/New_York
      - HOSTNAME=prosody
    volumes:
      - "/srv/$USER/docker/casjaysdevdocker/prosody/prosody/latest/volumes/data:/data:z"
      - "/srv/$USER/docker/casjaysdevdocker/prosody/prosody/latest/volumes/config:/config:z"
    ports:
      - 80:80
    restart: always
```
  
## Get source files  
  
```shell
dockermgr download src casjaysdevdocker/prosody
```
  
OR
  
```shell
git clone "https://github.com/casjaysdevdocker/prosody" "$HOME/Projects/github/casjaysdevdocker/prosody"
```
  
## Build container  
  
```shell
cd "$HOME/Projects/github/casjaysdevdocker/prosody"
buildx 
```
  
## Authors  
  
🤖 casjay: [Github](https://github.com/casjay) 🤖  
⛵ casjaysdevdocker: [Github](https://github.com/casjaysdevdocker) [Docker](https://hub.docker.com/u/casjaysdevdocker) ⛵  
