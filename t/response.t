#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 17;

use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok 'ReAnimator::WebSocket::Response';

my $res = ReAnimator::WebSocket::Response->new;
$res->checksum('fQJ,fN/4F4!~K~MH');
$res->host('example.com');
$res->resource_name('/demo');
$res->origin('file://');

my $string = '';
$string .= "HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a";
$string .= "Upgrade: WebSocket\x0d\x0a";
$string .= "Connection: Upgrade\x0d\x0a";
$string .= "Sec-WebSocket-Origin: file://\x0d\x0a";
$string .= "Sec-WebSocket-Location: ws://example.com/demo\x0d\x0a";
$string .= "\x0d\x0a";
$string .= "fQJ,fN/4F4!~K~MH";

is $res->to_string => $string;

$res = ReAnimator::WebSocket::Response->new;
$res->version(75);
$res->host('example.com');

$string = '';
$string .= "HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a";
$string .= "Upgrade: WebSocket\x0d\x0a";
$string .= "Connection: Upgrade\x0d\x0a";
$string .= "\x0d\x0a";

is $res->to_string => $string;

$res = ReAnimator::WebSocket::Response->new;
$res->version(75);
$res->host('example.com');
$res->resource_name('/demo');
$res->origin('file://');
$res->cookie(name => 'foo', value => 'bar', path => '/');

$string = '';
$string .= "HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a";
$string .= "Upgrade: WebSocket\x0d\x0a";
$string .= "Connection: Upgrade\x0d\x0a";
$string .= "Set-Cookie: foo=bar; Path=/; Version=1\x0d\x0a";
$string .= "\x0d\x0a";

is $res->to_string => $string;

$res = ReAnimator::WebSocket::Response->new(
    number1 => 777_007_543,
    number2 => 114_997_259,
    key3    => "\x47\x30\x22\x2D\x5A\x3F\x47\x58"
);
ok $res->parse("HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a");
ok $res->parse("Upgrade: WebSocket\x0d\x0a");
ok $res->parse("Connection: Upgrade\x0d\x0a");
ok $res->parse("Sec-WebSocket-Origin: file://\x0d\x0a");
ok $res->parse("Sec-WebSocket-Location: ws://example.com/demo\x0d\x0a");
ok $res->parse("\x0d\x0a");
ok $res->parse("0st3Rl&q-2ZU^weu");
ok $res->is_done;

is $res->challenge => '0st3Rl&q-2ZU^weu';
ok !$res->secure;
is $res->host          => 'example.com';
is $res->resource_name => '/demo';
is $res->origin        => 'file://';
