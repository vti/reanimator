package ReAnimator::WebSocket::Response;

use strict;
use warnings;

use ReAnimator::WebSocket::Location;
use ReAnimator::WebSocket::Cookie::Response;

sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $self = {@_};
    bless $self, $class;

    $self->version(76);

    $self->{cookies} ||= [];

    return $self;
}

sub version { @_ > 1 ? $_[0]->{version} = $_[1] : $_[0]->{version} }

sub origin { @_ > 1 ? $_[0]->{origin} = $_[1] : $_[0]->{origin} }
sub host   { @_ > 1 ? $_[0]->{host}   = $_[1] : $_[0]->{host} }
sub secure { @_ > 1 ? $_[0]->{secure} = $_[1] : $_[0]->{secure} }

sub resource_name {
    @_ > 1 ? $_[0]->{resource_name} = $_[1] : $_[0]->{resource_name};
}

sub checksum { @_ > 1 ? $_[0]->{checksum} = $_[1] : $_[0]->{checksum} }

sub location {
    my $self = shift;

    return ReAnimator::WebSocket::Location->new(
        host          => $self->host,
        secure        => $self->secure,
        resource_name => $self->resource_name,
    )->to_string;
}

sub cookies { @_ > 1 ? $_[0]->{cookies} = $_[1] : $_[0]->{cookies} }

sub cookie {
    my $self = shift;

    push @{$self->{cookies}}, ReAnimator::WebSocket::Cookie::Response->new(@_);
}

sub to_string {
    my $self = shift;

    my $string = '';

    $string .= "HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a";

    $string .= "Upgrade: WebSocket\x0d\x0a";
    $string .= "Connection: Upgrade\x0d\x0a";

    if ($self->version > 75) {
        $string .= 'Sec-WebSocket-Origin: ' . $self->origin . "\x0d\x0a";
        $string .= 'Sec-WebSocket-Location: ' . $self->location . "\x0d\x0a";
    }

    if (@{$self->cookies}) {
        $string .= 'Set-Cookie: ';
        $string .= join ',' => $_->to_string for @{$self->cookies};
        $string .= "\x0d\x0a";
    }

    $string .= "\x0d\x0a";

    $string .= $self->checksum if $self->version > 75;

    return $string;
}

1;
