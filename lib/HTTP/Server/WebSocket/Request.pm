package HTTP::Server::WebSocket::Request;

use strict;
use warnings;

use base 'HTTP::Server::WebSocket::Stateful';

use Digest::MD5 'md5';

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{fields} = {};

    $self->version(76);
    $self->state('request_line');

    return $self;
}

sub version { @_ > 1 ? $_[0]->{version} = $_[1] : $_[0]->{version} }

sub challenge { @_ > 1 ? $_[0]->{challenge} = $_[1] : $_[0]->{challenge} }
sub path { @_ > 1 ? $_[0]->{path} = $_[1] : $_[0]->{path} }

sub parse {
    my $self  = shift;
    my $chunk = shift;

    return 1 unless length $chunk;

    $self->{buffer} .= $chunk;
    $chunk = $self->{buffer};

    while ($chunk =~ s/^(.*?)\x0d\x0a//) {
        my $line = $1;

        if ($self->state eq 'request_line') {
            my ($req, $path, $http) = split ' ' => $line;
            return unless $req && $path && $http;

            return unless $req eq 'GET' && $http eq 'HTTP/1.1';

            $self->path($path);

            $self->state('fields');
        }
        elsif ($line ne '') {
            my ($name, $value) = split ':' => $line => 2;
            $value =~ s/^ // if defined $value && $value ne '';

            $self->{fields}->{$name} = $value;
        }
        else {
            $self->state('body');
        }
    }

    if ($self->state eq 'body') {
        if ($self->key1 && $self->key2) {
            return 1 unless length $chunk == 8;

            $self->challenge($chunk);
        }
        else {
            $self->version(75);
        }

        $self->done;
    }

    return 1;
}

sub origin { shift->{fields}->{'Origin'} }
sub host   { shift->{fields}->{'Host'} }

sub checksum {
    my $self = shift;

    my $key1      = pack 'N' => $self->key1;
    my $key2      = pack 'N' => $self->key2;
    my $challenge = $self->challenge;

    return md5 $key1 . $key2 . $challenge;
}

sub key1 {
    my $self = shift;

    my $key = $self->{fields}->{'Sec-WebSocket-Key1'};
    return unless $key;

    return $self->key($key);
}

sub key2 {
    my $self = shift;

    my $key = $self->{fields}->{'Sec-WebSocket-Key2'};
    return unless $key;

    return $self->key($key);
}

sub key {
    my $self = shift;
    my $key  = shift;

    my $number = '';
    while ($key =~ m/(\d)/g) {
        $number .= $1;
    }
    $number = int($number);

    my $spaces = 0;
    while ($key =~ m/ /g) {
        $spaces++;
    }

    if ($spaces == 0) {
        die 'FUCK';
    }

    return $number / $spaces;
}

1;
