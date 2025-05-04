# Rustic OSM Map Tiles

```
docker build -t rustic-tileserver:latest .
```

```
docker run --name rustic-dev-container -p 3000:3000 --mount type=bind,src=./tmp,dst=/var/tmp/rustic --mount type=bind,src=./server,dst=/usr/src/app rustic-tileserver:latest
```

```
docker start rustic-dev-container -i
```