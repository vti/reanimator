package ReAnimator::AtomDecorator;

use strict;
use warnings;

use ReAnimator::WebSocket::Handshake;
use ReAnimator::WebSocket::Frame;

require Carp;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    my $atom = $self->atom;
    Carp::croak qq/Something went wrong during atom decoration/ unless $atom;

    $self->{frame} = $self->_build_frame;
    $self->{handshake} = $self->_build_handshake(secure => $atom->secure);

    $self->{on_message}   ||= sub { };
    $self->{on_handshake} ||= sub { };

    return $self;
}

sub _build_frame     { shift; ReAnimator::WebSocket::Frame->new(@_) }
sub _build_handshake { shift; ReAnimator::WebSocket::Handshake->new(@_) }

sub atom  { shift->{atom} }
sub frame { shift->{frame} }

sub handshake { @_ > 1 ? $_[0]->{handshake} = $_[1] : $_[0]->{handshake} }

sub on_message { @_ > 1 ? $_[0]->{on_message} = $_[1] : $_[0]->{on_message} }

sub on_handshake {
    @_ > 1 ? $_[0]->{on_handshake} = $_[1] : $_[0]->{on_handshake};
}

sub error { shift->atom->error(@_) }
sub write { shift->atom->write(@_) }

sub _parse_frames {
    my ($self, $chunk) = @_;

    my $frame = $self->frame;
    $frame->append($chunk);

    while (my $message = $frame->next) {
        $self->on_message->($self, $message);
    }
}

sub send_message {
    my ($self, $message) = @_;

    my $frame = ReAnimator::WebSocket::Frame->new($message);
    $self->write($frame->to_string);
}

1;
