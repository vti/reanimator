#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;

use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok 'HTTP::Server::WebSocket::Location';

my $l = HTTP::Server::WebSocket::Location->new(
    host   => 'foo.com',
    secure => 1
);
is $l->to_string => 'wss://foo.com/';

$l = HTTP::Server::WebSocket::Location->new(
    host          => 'foo.com',
    resource_name => '/demo'
);
is $l->to_string => 'ws://foo.com/demo';
