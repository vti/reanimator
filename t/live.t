#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;

#BEGIN { $ENV{EVENT_REACTOR_DEBUG} = 1 }

use EventReactor;

my $event_reactor = EventReactor->new(
    address   => 'localhost',
    port      => 3000,
    on_accept => sub {
        my ($self, $client) = @_;

        $client->on_read(
            sub {
                my ($client, $chunk) = @_;

                is $chunk => 'Hello!';

                $self->stop;
            }
        );

        $client->write('Hello!');
    }
)->listen;

$event_reactor->connect(
    on_connect => sub {
        my ($atom) = @_;
    },
    on_read => sub {
        my ($atom, $chunk) = @_;

        $atom->write($chunk);
    }
);

$event_reactor->start;
