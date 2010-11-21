#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 24;

use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok 'ReAnimator::WebSocket::URL';

my $url = ReAnimator::WebSocket::URL->new;
ok $url->parse('ws://example.com');
ok !$url->secure;
is $url->host          => 'example.com';
is $url->resource_name => '/';

$url = ReAnimator::WebSocket::URL->new;
ok $url->parse('ws://example.com/');
ok !$url->secure;
is $url->host          => 'example.com';
is $url->resource_name => '/';

$url = ReAnimator::WebSocket::URL->new;
ok $url->parse('ws://example.com/demo');
ok !$url->secure;
is $url->host          => 'example.com';
is $url->resource_name => '/demo';

$url = ReAnimator::WebSocket::URL->new;
ok $url->parse('ws://example.com:3000');
ok !$url->secure;
is $url->host          => 'example.com';
is $url->port          => '3000';
is $url->resource_name => '/';

$url = ReAnimator::WebSocket::URL->new;
ok $url->parse('ws://example.com/demo?foo=bar');
ok !$url->secure;
is $url->host          => 'example.com';
is $url->resource_name => '/demo';

$url = ReAnimator::WebSocket::URL->new(host => 'foo.com', secure => 1);
is $url->to_string => 'wss://foo.com/';

$url = ReAnimator::WebSocket::URL->new(
    host          => 'foo.com',
    resource_name => '/demo'
);
is $url->to_string => 'ws://foo.com/demo';
