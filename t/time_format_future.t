# vi:filetype=perl

# Use libfaketime to test the txid results in the future. This ensures that the
# format of the encoded id continues to increase lexically as expected.
$ENV{FAKETIME} = '@2109-01-13 14:24:48';

use Test::Nginx::Socket;

repeat_each(50);
log_level('debug');
workers(4);

plan tests => repeat_each() * (2 * blocks());
run_tests();

__DATA__

=== TEST 1: format of the encoded timestamp in the future
--- config
    location /random {
      return 200 "$txid";
    }
--- request
    GET /random
--- response_body_like: ^vthkn[0-9a-v]{15}$
