# Docker fast track

During this lab we are going to use several basic docker commands to accomplish 80% of the daily tasks related to develope a container oriented application.

## Docker Hub

* Register a Docker Hub account
* Go to [Play with Docker](https://labs.play-with-docker.com/) and login using it
* Create an instance

## Basic commands

* Retrieving the image

```bash
docker pull mysql:5
docker history mysql:5
docker images
```

* Creating the network

```bash
docker network create net_$USER
```

* Running `mysql` container in the background

```bash
docker run \
  -d \
  --name pokemondb_$USER \
  --network net_$USER \
  -e MYSQL_ROOT_PASSWORD=mySecretPassword \
  mysql:5
```

* Trying useful commands

```bash
docker ps
docker logs pokemondb_$USER
docker inspect pokemondb_$USER
docker top pokemondb_$USER
docker stats pokemondb_$USER
docker diff pokemondb_$USER
```

## Connecting to an existing container

* Running an interactive command inside existing container

```bash
docker exec -it pokemondb_$USER bash
```

* Playing with it

```bash
> whereis mysqld
> exit
```

## Communications between containers

* Executing a tooling container (with `bash`, in this case)

```bash
docker run \
  -it \
  --rm \
  --network net_$USER \
  -e DB=pokemondb_$USER \
  bash
```

* Checking communications from inside the new container

```
> ping $DB
> apk add busybox-extras
> telnet $DB:3306
> exit
```

## Volumes

* Downloading `sql` file with a *pokemon* database

```bash
wget https://raw.githubusercontent.com/ciberado/pokemon-nodejs/v0.0.4-mysql/database.sql
cat database.sql
```

* Launching a tooling container with `mysql-client` and the dump file mounted as volume

```bash
docker run \
  -it \
  --network net_$USER \
  --rm \
  -v $(pwd):/dump \
  -e DB=pokemondb_$USER \
  mysql:5 sh
```

* Importing the sql file from inside the container

```bash
> ls /dump
> mysql -h $DB -P 3306 -uroot -pmySecretPassword < /dump/database.sql
> echo "use pokemondatabase; select count(*) from pokemon;" | mysql -h $DB -P 3306 -uroot -pmySecretPassword
> exit
```

## Dev environments

In a real scenario, you will be able to edit the code from outside the container.

* Download the code

```bash
git clone https://github.com/ciberado/pokemon-nodejs
cd pokemon-nodejs
git checkout v0.0.4-mysql
```

* Execute the development container

```bash
docker run \
  -it \
  --network net_$USER  \
  -e DB=pokemondb_$USER \
  -v $(pwd):/app \
  -p 8080:8080 \
  -p 9229:9229 \
  node:10 bash
```

* Start the application inside the container

```bash
> cd /app
> npm install
> export PORT=$(( ( RANDOM % 1000 )  + 8080 ))
> export HOST=$DB
> export USER=root
> export PASSWORD=mySecretPassword
> export DATABASE=pokemondatabase
> npm start 
```

## Prune

```bash
docker ps -q
docker stop $(docker ps -q)
docker ps -aq
docker rm $(docker ps -aq)
docker rmi $(docker images)
docker system prune --all
```

