# vi:filetype=perl

delete $ENV{FAKETIME};

use Test::Nginx::Socket;

repeat_each(50);
log_level('debug');
workers(4);

# This test ensures that the generated ids are lexically sortable over time and
# unique across multiple request.
#
# Performing this type of test across multiple requests seems a little tricky
# to accomplish with Test::Nginx. This approach appends each body seen to a
# global array after each response comes back. Then after each test, we make
# sure the array of responses is in sorted order. This relies on the fact that
# we're making multiple requests via repeat_each(50) above.
our @all_bodies = ();
our %uniq_bodies = ();
add_response_body_check(sub {
    use Time::HiRes;
    my ($block, $body, $req_idx, $repeated_req_idx, $dry_run) = @_;

    SKIP: {
        # Briefly sleep between requests to ensure the initial timestamp portion
        # of the id will increase..
        Time::HiRes::sleep(0.1);

        push(@all_bodies, $body);
        $uniq_bodies{$body}++;

        # Ensure all the response bodies seen so far containing txids are in
        # sorted order over time.
        my @expected_bodies_order = sort(@all_bodies);
        is_deeply(\@all_bodies, \@expected_bodies_order, "txids are sorted (req $repeated_req_idx)" );

        # Ensure that each response body seen containing a txid is unique so far.
        my $actual_uniq_bodies = scalar(keys(%uniq_bodies));
        my $expected_uniq_bodies = $repeated_req_idx + 1;
        is($actual_uniq_bodies, $expected_uniq_bodies, "txids are unique (req $repeated_req_idx)" );
    }
});

plan tests => repeat_each() * (4 * blocks());
run_tests();

__DATA__

=== TEST 1: lexically sortable and unique
--- config
    location /random {
      return 200 "$txid";
    }
--- request
    GET /random
--- response_body_like: ^[0-9a-v]{20}$
