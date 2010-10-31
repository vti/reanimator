package HTTP::Server::WebSocket::Handshake;

use strict;
use warnings;

use HTTP::Server::WebSocket::Request;
use HTTP::Server::WebSocket::Response;

sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $self = {@_};
    bless $self, $class;

    $self->{req} = HTTP::Server::WebSocket::Request->new;
    $self->{res} = HTTP::Server::WebSocket::Response->new;

    return $self;
}

sub is_done { shift->{req}->is_done }

sub res {
    my $self = shift;

    my $req = $self->{req};
    my $res = $self->{res};

    $res->checksum($req->checksum);
    $res->origin($req->origin);
    $res->host($req->host);
    $res->path($req->path);

    return $res;
}

sub parse {
    my $self  = shift;
    my $chunk = shift;

    return 1 if $self->is_done;

    return $self->{req}->parse($chunk);
}

1;
