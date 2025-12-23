# 🚴 Deploying Beefsteak

These are step-by-step instructions on how to deploy your own machine serving Beefsteak map tiles. We're assuming you're relatively comfortable in the terminal but aren't necessarily a sysadmin. These instruction come with no warranty as per the [MIT license](/LICENSE).

## Preparing the server

### Choosing a setup

First things first, you'll need a beefy server. We use a dedicated [Hetzner](https://www.hetzner.com) box but there are many options on the market. The exact specs depend on your use case, but for serving the full planet we recommend at minimum:

- **64 GB RAM**: The scripts are configured to scale Postgres performance based on available RAM, so the more RAM the better. Less RAM is supported but performance may suffer.
- **2 TB SSD**: While the compressed OSM planetfile is less than 100 GB, much more space is required to fit the expanded database tables.
- **Ubuntu 24**: Beefsteak has not been tested on other Linux versions.

While it's possible to run Beefsteak on a server that also handles other processes, this use case is not tested and is not recommended for production.

### Configuring drives

Many production servers have multiple drives, in which case you may need to configure one logical volume (e.g. a RAID array) that will fit all your data. This may be separate from your boot volume. Beefsteak uses `/var/lib/app` as the working directory for all large files, including the Postgres database, so you can mount your large volume here.

For example, say your server has two 1 TB drives and one 256 GB drive. You'll want to install Ubuntu on the 256 GB drive as your boot volume (the default ext4 format is fine) and configure the two 1 TB drives into a single 2 TB striped RAID array (probably in XFS format for better performance). Then, connect to your Ubuntu installation and persistently mount your RAID array to `/var/lib/app`:

```
sudo mkdir -p /var/lib/app
echo '/dev/md0 /var/lib/app xfs defaults,noatime,nodiratime,allocsize=1m 0 0' | sudo tee -a /etc/fstab
systemctl daemon-reload
sudo mount -a
df -h | grep /var/lib/app
```

If your boot volume is 2 TB or greater to start, then you don't need to worry about this step.

## Loading the database and starting the tileserver

Once you've acquired a server, configured your drives, and installed Ubuntu, open your terminal and `ssh` into it:

```
ssh root@your.servers.ip.address
```

For security and compatibility, you'll probably want to run updates after a fresh Ubuntu install:

```
sudo apt update
sudo apt upgrade
```

Reboot to apply updates:

```
reboot
```

You'll need to `ssh` back in after the reboot.

Next, install `git` if your distribution doesn't include it by default:

```
sudo apt update && sudo apt install -y git
```

Now, clone the Beefsteak repo onto your server:

```
git clone https://github.com/waysidemapping/beefsteak-map-tiles.git /usr/src/app
```

To make advanced customizations, you can fork the repo and clone your fork instead.

From here on it's recommended to use a terminal multiplexer like [`tmux`](https://github.com/tmux/tmux/wiki) to manage your session. This will ensure the setup and serve processes are not interrupted even if you get disconnected.

```
tmux new
```

You can detach from this session (type <kbd>Ctrl</kbd><kbd>B</kbd>, then <kbd>D</kbd>) or reattach (`tmux attach`) at any time.

Now you're ready to run the [start.sh](/server/start.sh) script:

```
bash /usr/src/app/server/start.sh
```

This is a long script designed to automate a lot of the finicky details around setting up the tileserver. These steps include:

- Create required users and directories
- Install the Martin tileserver from binary
- Build and install osm2pgsql from source
- Install and configure Postgres and PostGIS
- Download the OSM planet file
- Use osm2pgsql to import the planet into Postgres using the Beefsteak table definitions (this is the longest part)
- Run post-import follow-up commands in Postgres needed for Beefsteak (this can also be long)
- Load Beefsteak's tile rendering functions into Postgres
- Start the Varnish cache
- Start the Martin tileserver

The whole process may take up to 36 hours depending on your machine. Generally you can rerun the start script at any time to restart the server, and completed steps will be skipped.

For total control, or if you run into issues, you can choose to dissect the script yourself and run each command manually.

Eventually you should see a message like:

```
[2025-12-18T20:28:26Z INFO  martin] Martin has been started on 127.0.0.1:3000.
```

At this point you can leave Martin running and exit the `tmux` session by typing <kbd>Ctrl</kbd><kbd>B</kbd>, then <kbd>D</kbd>.

You can test that Martin is running. This should give you `HTTP/1.1 200 OK`:

```
curl -I http://127.0.0.1:3000/beefsteak
```

However, this should not be directly accessible externaly. This should fail:

```
curl -I http://your.servers.ip.address:3000/beefsteak
```

The Varnish endpoint should succeed with `HTTP/1.1 200 OK`:

```
curl -I http://your.servers.ip.address/beefsteak
```

### Troubleshooting

If your initial data import started but failed to complete, you may have incomplete data in your database. You'll need to drop the database before trying again:

```
sudo -u postgres psql --command="DROP DATABASE osm;"
```

## Warming the cache

Even though Beefsteak supports minutely updates from OSM, some tile caching is still required to achieve decent performance. This is particularly true at low zoom levels, where some tiles can take a few minutes to render. An [optional script](/server/warm_tile_cache.sh) is included to "warm up" the cache with low zoom tiles. You'll probably want to run this after loading the database but before zooming and panning around your map:

```
bash /usr/src/app/server/warm_tile_cache.sh
```

Tiles are cached in memory, not disk, so whenever your restart your server you'll need to run this script again. Low zoom tiles are cached longer than high zoom tiles (see the [config](/server/config/varnish_config.vcl) for details).

You can test the Varnish cache by requesting the same tile twice:

```
curl -I http://127.0.0.1:3000/beefsteak/14/4948/6103
```

## Updating

```
rm -rf /usr/src/app
git clone https://github.com/waysidemapping/beefsteak-map-tiles.git /usr/src/app
```

```
bash /usr/src/app/server/update_sql_functions.sh
```