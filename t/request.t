#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 20;

use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok 'HTTP::Server::WebSocket::Request';

my $req = HTTP::Server::WebSocket::Request->new;

is $req->state => 'request_line';
ok !$req->is_done;
ok $req->parse;
ok $req->parse('');
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
is $req->state => 'fields';

$req->parse("Upgrade: WebSocket\x0d\x0a");
is $req->state => 'fields';
$req->parse("Connection: Upgrade\x0d\x0a");
is $req->state => 'fields';
$req->parse("Host: http://example.com\x0d\x0a");
is $req->state => 'fields';
$req->parse("Origin: http://example.com\x0d\x0a");
is $req->state => 'fields';
$req->parse(
    "Sec-WebSocket-Key1: 18x 6]8vM;54 *(5:  {   U1]8  z [  8\x0d\x0a");
$req->parse("Sec-WebSocket-Key2: 1_ tx7X d  <  nw  334J702) 7]o}` 0\x0d\x0a");
is $req->state => 'fields';
$req->parse("\x0d\x0aTm[K T2u");
is $req->state     => 'done';
is $req->key1      => '155712099';
is $req->key2      => '173347027';
is $req->challenge => 'Tm[K T2u';

is $req->path     => '/demo';
is $req->host     => 'http://example.com';
is $req->origin   => 'http://example.com';
is $req->checksum => 'fQJ,fN/4F4!~K~MH';
