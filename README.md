Overview
========

`ngx_txid` is a module that exposes `$txid`: a cached, request scoped, 20
character, base32hex encoded, temporally and lexically sortable, case
insensitive, 96 bit identifier.

Use `$txid` to correlate logs or upstream requests.

Build
=====

  * Configure and nginx with `--add-module=path/to/ngx_txid`

Example
=======

Assuming you want to to store your logs in column format.  You'll need a join
key for each request even across connections regardless of how accurate the
scheduler is from your `timer_resolution` directive.  The remaining columns can
be specific per data logged.

```
    log_format agent     '$txid $http_user_agent';
    log_format referrer  '$txid $http_referer';
    log_format peer      '$txid $remote_addr';
    log_format status    '$txid $status';
    log_format request   '$txid $request';
    log_format conn      '$txid conn:$connection reqs:$connection_requests pipe:$pipe';

    server {
        listen       80;
        server_name  example.com;
        access_log   logs/example.com/conns.log conn;
        access_log   logs/example.com/agents.log agent;

        location / {
            remove_header    X-Request-Id;
            add_header       X-Request-Id $txid;
            proxy_set_header X-Request-Id $txid;
            proxy_pass       http://localhost:8080;
        }
    }
```

Background
==========

The design of this transaction ID should meet the following requirements:

  * Be roughly numerically temporally sortable with ~second granularity.
  * Have a representation that is roughly lexically sortable with ~second granularity.
  * Have a probability of less than 1e-9 for collision at 1 million transactions per second.
  * Be efficient and easy to decode into fixed size C types
  * Always be available at the risk of higher collision probability
  * Use as few bytes as possible
  * Work with IPv4 and IPv6 networks

Technique
=========

Use a monotonic millisecond resolution clock in the high 42 bits and system
entropy for the low 54 bits.  Use enough entropy bits to satisfy a collision
probability at a desired global request rate.

+------------- 64 bits------------+--- 32 bits ----+
+------ 42 bits ------+--22 bits--|----------------+
| msec since 1970-1-1 | random    | random         |
+---------------------+-----------+----------------+

A request rate of 1 million per second across all servers means 1000 random
values per millisecond.  Estimating the collision probability using the
[birthday paradox](http://en.wikipedia.org/wiki/Birthday_problem) can be done
with this formula: `1 - e^(-((m^2)/(2*n)))` where `m` is the number of ids and
`n` is the number of random values possible.

When using 54 bits of entropy:

```
1mil req/s  = 1 - exp(-((1000^2) /(2*2^54))) = 2.775558e-11
10mil req/s = 1 - exp(-((10000^2)/(2*2^54))) = 2.775558e-09
```

The odds of collision are small even at 10 million requests per second.

Nginx keeps track of the current clock in increments of the configuration
directive `timer_resolution`.  The clock resolution for `$txid` is 1ms, so a
timer resolution greater than 1ms means that the probability of collision will
increase.  If you have a `timer_resolution` of 10ms, 1 million requests per
second would require 10,000 random values per second in the worst case.

Encoding
========

Base32hex is used with a lower case alphabet and without padding characters is
chosen for the following reasons:

  * lexically sort order equivalent to numeric sort order
  * case insensitive equality
  * lower case is easer for visual compares
  * denser than hex encoding by 4 bytes


Other techniques
================

  * [snowflake](https://github.com/twitter/snowflake): uses time(41) + unique id(10) + sequence(12).
    * Pro: guaranteed unique sequences
    * Pro: fits in 63 bits
    * Cons: requires unique id coordination for each server - 16 workers processes per host means a limit of 64 instances of nginx
    * Cons: only 11 bits available for unique id, needs monitoring
    * Cons: total ordering only possible in the same process
    * Cons: service interruption possible when clocks lose synchronization

  * [flake](http://boundary.com/blog/2012/01/12/flake-a-decentralized-k-ordered-unique-id-generator-in-erlang/): uses time + mac id + sequence.
    * Pro: guaranteed unique sequences
    * Cons: uses 128 bits
    * Cons: wastes 22 bits of timestamp data
    * Cons: only a single process per host can generate ids - needs to synchronize access to the sequence from each worker process
    * Cons: service interruption possible when clocks lose synchronization
    * Cons: needs cross platform MAC Address lookup.

  * [UUIDv4](http://www.ietf.org/rfc/rfc4122.txt): 122 bits of entropy
    * Pro: very low probability of collision
    * Cons: unsortable

  * [UUID with timestamp](http://www.ietf.org/rfc/rfc4122.txt): 48 bits of time + 74 bits entropy
    * Pro: very low probability of collision
    * Cons: string representation is not temporally local

  * [httpd mod\_unique\_id](http://httpd.apache.org/docs/2.4/mod/mod_unique_id.html): host ip(32) + pid(32) + time(32) + sequence (16) + thread id (32)
    * Pro: deterministic
    * Cons: uses 144 bits
    * Cons: assumes unique IPv4 for the hostnamme's interface
    * Cons: unsortable case-sensitive custom representation - base64 with a custom alphabet
    * Cons: hard limit of 65535 ids per second per pid - small tolerance for clock steps

Testing
=======

This module uses the perl [Test::Nginx](https://github.com/agentzh/test-nginx)
module with tests in the `t` directory with a specialized build of nginx of the
version specified in `Makefile`

```
cpan install Test::Nginx
make test
```

Memory profiling of the tests can be performed when `valgrind` is installed.

```
make grind
```
