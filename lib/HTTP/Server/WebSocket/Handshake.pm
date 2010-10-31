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

    return $self;
}

sub is_done { shift->{req}->is_done }

sub res {
    my $self = shift;

    my $req = $self->{req};

    my $res = HTTP::Server::WebSocket::Response->new(
        version       => $req->version,
        host          => $req->host,
        secure        => 0,
        resource_name => $req->resource_name,
        origin        => $req->origin
    );

    $res->checksum($req->checksum) if $req->version > 75;

    return $res;
}

sub parse {
    my $self  = shift;
    my $chunk = shift;

    return 1 if $self->is_done;

    return $self->{req}->parse($chunk);
}

1;
