package ReAnimator::Server;

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

    $atom->on_read(sub { $self->parse($_[1]) });

    $self->{frame} = ReAnimator::WebSocket::Frame->new;
    $self->{handshake} =
      ReAnimator::WebSocket::Handshake->new(secure => $atom->secure);

    $self->{on_message}   ||= sub { };
    $self->{on_handshake} ||= sub { };

    $self->{on_request} ||= sub { };

    return $self;
}

sub atom { shift->{atom} }

sub handshake { @_ > 1 ? $_[0]->{handshake} = $_[1] : $_[0]->{handshake} }

sub on_message { @_ > 1 ? $_[0]->{on_message} = $_[1] : $_[0]->{on_message} }

sub on_handshake {
    @_ > 1 ? $_[0]->{on_handshake} = $_[1] : $_[0]->{on_handshake};
}

sub on_request {
    @_ > 1 ? $_[0]->{on_request} = $_[1] : $_[0]->{on_request};
}

sub parse {
    my $self  = shift;
    my $chunk = shift;

    unless ($self->handshake->is_done) {
        my $handshake = $self->handshake;

        my $rs = $handshake->parse($chunk);
        unless (defined $rs) {
            $self->error($handshake->error);
            return;
        }

        if ($handshake->is_done) {
            $self->on_request->($self, $self->handshake);

            $self->write(
                $handshake->res->to_string => sub {
                    my $atom = shift;

                    $self->on_handshake->($self);
                }
            );

            return 1;
        }
    }

    my $frame = $self->{frame};
    $frame->append($chunk);

    while (my $message = $frame->next) {
        $self->on_message->($self, $message);
    }

    return 1;
}

sub error { shift->atom->error(@_) }
sub write { shift->atom->write(@_) }

sub send_message {
    my $self    = shift;
    my $message = shift;

    unless ($self->handshake->is_done) {
        Carp::carp qq/Can't send_message, handshake is not done yet./;
        return;
    }

    my $frame = ReAnimator::WebSocket::Frame->new($message);
    $self->write($frame->to_string);
}

1;
