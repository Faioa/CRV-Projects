## 1 - We create a Docker network to connect the Redis node and database
```
$ docker network create redis-network --subnet 172.18.0.0/24
```

## 2 - Redis database

We launch an instance of Redis' official image with the command :
```
$ docker run --name redis\
    --privileged\
    --network=redis-network\
    --ip 172.18.0.2\
    -d redis
```

We can find the address and port of the database with the following command :
```
$ docker container inspect redis
```
In our case, the default port is **6379** and its address is **172.18.0.2**.

## 3 - Node.js server

We use yarn to install the dependencies.
```
$ yarn
```

We use this command to build the docker image using the Dockerfile :
```
$ docker build -t tme6-node-redis-image <PATH>
```

We can now run the node-redis container with the command :
```
$ docker run --name node-redis\
    --network=redis-network\
    --ip 172.18.0.3\
    --publish 3000:3000\
    -d tme6-node-redis-image
```

Now both are connected, we only need to add the frontend node.

Also, we can find it's port and address with the same command as before :
```
$ docker container inspect node-redis
```
In our case, its port is **3000** and its address is **172.18.0.3**, but it is available on *localhost:3000* because of the *--publish 3000:3000* option.

## 4 - Deploying frontend

We use the following commands to install dependencies and build the project :
```
$ yarn
$ yarn build
```

Then, we can build a Docker image using a Dockerfile.
```
$ docker build -t tme6-redis-react-image <PATH>
```

Finally, we can run the container.
```
$ docker run --name redis-react\
    --publish 8080:3000\
    -d tme6-redis-react-image
```
And run it with the URL *localhost:8080*.

## Conclusion

It is now functionning without the http tunnels. To use them, we can add 2 steps to the process :

- After running the *node-redis* container, we can open an http tunnel to the linked to the port **3000** (the host port in the *--publish* option) and use its URL to configure the frontend.
- After configuring the frontend and running the *redis-react* container, we can open another http tunnel linked to the port **8080** (the host port in the *--publish* option).

Then, our frontend and database (*node-redis* + *redis* containers) can be run on different machines over the Internet.
