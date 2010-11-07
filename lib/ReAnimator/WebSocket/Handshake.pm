package ReAnimator::WebSocket::Handshake;

use strict;
use warnings;

use ReAnimator::WebSocket::Request;
use ReAnimator::WebSocket::Response;

sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $self = {@_};
    bless $self, $class;

    $self->{req} = ReAnimator::WebSocket::Request->new;

    return $self;
}

sub secure { shift->{secure} }

sub error { shift->{error} }

sub is_done { shift->{req}->is_done }

sub res {
    my $self = shift;

    my $req = $self->{req};

    my $res = ReAnimator::WebSocket::Response->new(
        version       => $req->version,
        host          => $req->host,
        secure        => $self->secure,
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

    my $rs = $self->{req}->parse($chunk);
    unless (defined $rs) {
        $self->{error} = $self->{req}->error;
        return;
    }

    return $rs;
}

1;
