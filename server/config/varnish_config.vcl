vcl 4.1;

backend martin {
    .host = "127.0.0.1";
    .port = "3000";
    .first_byte_timeout = 600s;
    .between_bytes_timeout = 600s;
    .connect_timeout = 5s;
    .max_connections = 100;
}

sub vcl_hash {
    # Serve the same content for the same endpoint regardless of the host or server address,
    # e.g. accessing `curl http://127.0.0.1/beefsteak/0/0/0` will properly warm cache for a
    # public endpoint like `http://tiles.example.com/beefsteak/0/0/0`

    hash_data(req.url);
    # Manually return so the default parameters won't be added to the hash
    return (lookup);
}

sub vcl_recv {
    if (req.url ~ "^/beefsteak/") {
        set req.backend_hint = martin;

        # Always use cache even if client requests fresh
        unset req.http.Cache-Control;
        unset req.http.Pragma;
        # Remove cookies
        unset req.http.Cookie;

        # Remove query parameters
        set req.url = regsub(req.url, "\?.*$", "");
        # Remove trailing slash
        set req.url = regsub(req.url, "/$", "");
        # Collapse multiple slashes into one
        set req.url = regsuball(req.url, "//+", "/");

        return (hash);
    }
    return (pass);
}

sub vcl_backend_response {
    if (beresp.status >= 200 && beresp.status < 300) {
        if (bereq.url ~ "^/beefsteak/([0-9]+)/([0-9]+)/([0-9]+)(\\..*)?$") {

            # Set the url as a header so the ban lurker can access it
            set beresp.http.x-url = bereq.url;

            # Always gzip no matter what the client requested (won't double compress content)
            set beresp.do_gzip = true;

            # Set different cache policies depending on the zoom level
            # Match zoom 0-6
            if (bereq.url ~ "^/beefsteak/[0-6]/") {
                # Low-zoom tiles are expensive to render, but would also need to be re-rendered all the time if
                # set to expire from incoming edits, so just cache them for awhile without using bans
                set beresp.ttl = 1d;
                # If martin is overwhelemed then continue to use the cache for awhile
                set beresp.grace = 7d;
            # Match zoom 7-15
            # These zooms should correspond to the define_expire_output parameters in the osm2pgsql lua style
            } else if (bereq.url ~ "^/beefsteak/([7-9]|1[0-5])") {
                # For mid and high zooms we'll primarily use bans to expire stale tiles based on incoming edits,
                # so we can set a really long ttl
                set beresp.ttl = 30d;
                set beresp.grace = 1d;
            # Match all other zooms (very high zooms)
            } else {
                # For very high zoom tiles it's not efficient to calculate and implement bans,
                # but they're cheap to render, so just set a really short ttl
                set beresp.ttl = 1m;
                set beresp.grace = 1h;
            }
            # Don't keep cached tiles around after the grace period
            set beresp.keep = 0;

            set beresp.http.Cache-Control = "public";

            # Treat all variants as the same object
            unset beresp.http.Vary;
        }
    } else {
        # Don't cache error codes or other unexpected results
        set beresp.uncacheable = true;
    }
}

sub vcl_hit {
    if (req.url ~ "^/beefsteak/") {
        if (obj.ttl <= 0s && obj.grace > 0s) {
            set req.http.X-Cache = "GRACE-HIT";
        } else {
            set req.http.X-Cache = "HIT";
        }
    }
}

sub vcl_miss {
    if (req.url ~ "^/beefsteak/") {
        set req.http.X-Cache = "MISS";
    }
}

sub vcl_deliver {
    # Remove interal header
    unset resp.http.x-url;
    set resp.http.X-Cache = req.http.X-Cache;
    set resp.http.Access-Control-Allow-Origin = "*";
}

sub vcl_backend_error {
    set beresp.ttl = 30s;
    return (deliver);
}