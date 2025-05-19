# Rustic OSM Map Tiles

## Stack

- PostgreSQL/PostGIS
- osm2pgsql
- Martin

## Development

For convenience, a Dockerfile is provided that will run the server in an Ubuntu environment. Deploying the stack via Docker is intended for development only and has not been tested in production.

To build the reusable Docker image, run:

```
docker build -t rustic-tileserver:latest -f Dockerfile .
```

To create and start a container using the Docker image, run: 

```
docker run --name rustic-dev-container -p 3000:3000 --mount type=bind,src=./server,dst=/usr/src/app --mount type=bind,src=./tmp,dst=/var/tmp/app rustic-tileserver:latest
```

The first `--mount` is required to copy over the `/server` directory to the container. Any changes to these files will be immediately synced between the host and the container. The second `--mount` is optional but is convenient for managing intermediate files (which may be quite large) on the host system.

To restart the container once it's stopped, run:

```
docker start rustic-dev-container -i
```

To apply changes to `functions.sql` while the container (and Postgres) are running, run:

```
docker exec -i rustic-dev-container /usr/src/app/update_sql_functions.sh
```