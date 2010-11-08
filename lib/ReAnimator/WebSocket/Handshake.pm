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

    return $self;
}

sub secure { shift->{secure} }

sub error { shift->{error} }

sub is_done { shift->req->is_done }

sub req { shift->{req} ||= ReAnimator::WebSocket::Request->new }
sub res { shift->{res} ||= ReAnimator::WebSocket::Response->new }

sub parse {
    my $self  = shift;
    my $chunk = shift;

    return 1 if $self->is_done;

    my $req = $self->req;

    my $rs = $req->parse($chunk);
    unless (defined $rs) {
        $self->{error} = $req->error;
        return;
    }

    if ($req->is_done) {
        $self->_prepare_response;
    }

    return $rs;
}

sub _prepare_response {
    my $self = shift;

    my $req = $self->req;
    my $res = $self->res;

    $res->version($req->version);
    $res->host($req->host);
    $res->secure($self->secure);
    $res->resource_name($req->resource_name);
    $res->origin($req->origin);

    $res->checksum($req->checksum) if $req->version > 75;

    $self->{res} = $res;
}

1;
