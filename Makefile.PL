#!/usr/bin/env perl

use 5.008007;

use strict;
use warnings;

use ExtUtils::MakeMaker;

my ($mm) = $ExtUtils::MakeMaker::VERSION =~ /^([^_]+)/;

WriteMakefile(
    NAME         => 'HTTP::Server::WebSocket',
    VERSION_FROM => 'lib/HTTP/Server/WebSocket.pm',
    ABSTRACT     => 'Standalone single-process WebSocket server',
    AUTHOR       => 'Viacheslav Tykhanovskyi <vti@cpan.org>',

    ($mm < 6.3002 ? () : ('LICENSE' => 'artistic_2')),

    (   $mm < 6.46
        ? ()
        : ( META_MERGE => {
                requires  => {perl => '5.008007'},
                resources => {
                    repository =>
                      'http://github.com/vti/http-server-web-socket',
                    bugtracker =>
                      'http://github.com/vti/http-server-web-socket/isues',
                },
                no_index => {directory => [qw/t/]}
            },
            META_ADD => {
                build_requires     => {},
                configure_requires => {}
            },
        )
    ),

    PREREQ_PM => {
        'Digest::MD5' => 0,
        'Errno'       => 0,
        'IO::Poll'    => 0,
        'IO::Socket'  => 0,
        'URI'         => 0,
    },
    test => {TESTS => 't/*.t t/*/*.t'}
);
