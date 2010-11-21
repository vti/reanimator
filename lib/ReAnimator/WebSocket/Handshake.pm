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

sub req { shift->{req} ||= ReAnimator::WebSocket::Request->new }
sub res { shift->{res} ||= ReAnimator::WebSocket::Response->new }

1;
