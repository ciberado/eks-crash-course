# Dockerizing tools

## You will learn how to...

* Create images from a Dockerfile
* Pack a tool as an image with its dependencies
* Easily execute your dockerized toolchain

## Requisites

* It will be useful to have your own account in a registry, for example at http://hub.docker.io
* You will end earlier if you change all the XX for the real name of the repository in this file (for example, in my case it will be ciberado).

## The tool

We have developed our own version of the *excuse* command using nodejs:

```bash
mkdir excuses
cd excuses
```

``` javascript
cat << EOF > index.js
var fs = require('fs');
var excuse = fs.readFileSync('excuse.txt')
               .toString().split("\n");
var idx = process.argv.length >= 3 ? 
          process.argv[2] : 
		  Math.floor(Math.random() * excuse.length);
console.log(excuse[idx % excuse.length]);
EOF
```

Invoking the tool without any parameter will show a random qoute. If you use a numeric parameter it will show you the quote corresponding to that number in the index. Create the `excuses.txt` file

```bash
cat << EOF > excuse.txt
I have to floss my cat.
I've dedicated my life to linguine.
I want to spend more time with my blender.
The President said he might drop in.
The man on television told me to say tuned.
I've been scheduled for a karma transplant.
EOF
```

## Testing with interactive sessions

```
docker run -it --rm -v $(pwd):/app -w /app node:alpine node index.js $RANDOM
```


## The Dockerfile

The most interesting part of the `Dockerfile` is that it uses `ENTRYPOINT` to specify the command to be executed and `CMD` to provide default options (the first sentence of the file).

```
cat << EOF > Dockerfile
FROM node:alpine

COPY index.js excuse.txt ./

ENTRYPOINT ["node", "index.js"]
CMD ["0"]
EOF
```

## Building the image

From the directory that contains the project, execute:

```
REGISTRY_REPO=$USER
docker build -t $REGISTRY_REPO/excuse .
docker tag $REGISTRY_REPO/excuse $REGISTRY_REPO/excuse:latest
docker tag $REGISTRY_REPO/excuse $REGISTRY_REPO/excuse:0.0.1
docker images
```

As an option, you can upload it to the registry:

```
docker push $REGISTRY_REPO/excuse:latest
```

## Testing

Remember that by using `ENTRYPOINT` instead of just `CMD` the first parameter after the name of the image in the `run` command will be the first parameter passed to the entrypoint, not the name of the command to be executed inside the container.

```
docker run --rm -it $REGISTRY_REPO/excuse 

docker run --rm -it $REGISTRY_REPO/excuse 20
```

Even though, remember that with '--entrypoint' it is possible to rewrite the process launched by the container.

## Making execution easier

You can take advantage of the `alias` command in Unix or the `doskey` command in Windows to ease the invocation of the tool:

Linux
```
alias qt='docker run -it --rm $REGISTRY_REPO/excuse'
```

Windows
```
doskey qt=docker run --rm -it %REGISTRY_REPO%/excuse $*
```

Now you just need to invoke `qt` to launch your container.

## Conclusions

Well done! Now you are aware of how easily you can dockerize your tools, from *grunt* to different runtime versions of *nodejs*. And yes, you can also dockerize Docker but that is a story for another day.

