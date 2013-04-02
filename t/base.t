# vi:filetype=perl

use Test::Nginx::Socket;

repeat_each(17);
log_level('debug');
workers(4);

plan tests => repeat_each() * (2 * blocks());
run_tests();

__DATA__

=== TEST 1: single
--- config
    location /random {
      return 200 "$txid";
    }
--- request
    GET /random
--- response_body_like: ^[0-9a-v]{20}

=== TEST 2: reused cached per request
--- config
    location /random {
      return 200 "$txid $txid";
    }
--- request
    GET /random
--- response_body_like: ^([0-9a-v]{20}) \1

=== TEST 3: logged
--- http_config
    log_format random "random:$txid";
--- config
    access_log logs/error.log random;

    location /random {
      return 200 "$txid";
    }
--- request
    GET /random
--- response_body_like: ^[0-9a-v]{20}
--- error_log_like: random:[0-9a-v]{20}
