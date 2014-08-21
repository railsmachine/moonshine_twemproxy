# moonshine_twemproxy

A [moonshine](https://github.com/railsmachine/moonshine) plugin that installs and manages [twemproxy](https://github.com/twitter/twemproxy), a lightweight proxy for [memcached](http://memcached.org) and/or [redis](http://redis.io).

## Configuration

We use moonshine_twemproxy along with [moonshine_multi_server](https://github.com/railsmachine/moonshine_multi_server) and [moonshine_iptables](https://github.com/railsmachine/moonshine_iptables).

We *highly* recommend locking down access to just the servers that need it and limiting access just to the internal IP.

Here's an example configuration block for twemproxy:

```YAML
:twemproxy:
  :version: 0.3.0
  :listen: 0.0.0.0:6379
  :redis: true
  :hash: fnv1a_64
  :distribution: ketama
  :auto_eject_hosts: true
  :server_retry_timeout: 30000
  :server_failure_limit: 3
  :timeout: 400
  :servers:
  - 10.0.10.10:6379:1
  - 10.0.10.11:6379:1
```

### iptables

If you use moonshine_multi_server, you probably have a configuration builder for most things.  Here's the configuration builder we use to set up the iptables rules for twemproxy:

```ruby
def build_twemproxy_iptables_rules
  rules = build_base_iptables_rules
  
  (servers_with_rails_env + redis_servers + twemproxy_servers).each do |server|
    rules << "-A INPUT -s #{server[:internal_ip]} -p tcp -m tcp --dport 6379 -j ACCEPT"
  end

  {:rules => rules}
end
```

Right now, moonshine_twemproxy doesn't support multiple frontends - we only create one - but we'll add that if there's interest.

## Monitoring

The plugin sets up an xinetd service that returns the response from twemproxy's stat service.  It runs on localhost:1025.  This makes it really easy to add twemproxy stats to Scout using the Generic JSON Plugin!

***

Unless otherwise specified, all content copyright &copy; 2014, [Rails Machine, LLC](http://railsmachine.com)