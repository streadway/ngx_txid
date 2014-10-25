# vi:filetype=perl

# Use libfaketime to test the txid results in the past. This ensures that the
# format of the encoded id started at a lower lexical values as expected.
$ENV{FAKETIME} = '@1990-10-13 14:44:10';

use Test::Nginx::Socket;

repeat_each(50);
log_level('debug');
workers(4);

plan tests => repeat_each() * (2 * blocks());
run_tests();

__DATA__

=== TEST 1: format of the encoded timestamp in the past
--- config
    location /random {
      return 200 "$txid";
    }
--- request
    GET /random
--- response_body_like: ^4om9q[0-9a-v]{15}$
