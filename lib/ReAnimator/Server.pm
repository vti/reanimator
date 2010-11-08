package ReAnimator::Server;

use strict;
use warnings;

use base 'EventReactor::AcceptedAtom';

use ReAnimator::WebSocket::Handshake;
use ReAnimator::WebSocket::Frame;

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{frame}     = ReAnimator::WebSocket::Frame->new;
    $self->{handshake} = ReAnimator::WebSocket::Handshake->new(secure => $self->secure);

    $self->{on_message}   ||= sub { };
    $self->{on_handshake} ||= sub { };

    $self->{on_response} ||= sub { };

    return $self;
}

sub handshake { @_ > 1 ? $_[0]->{handshake} = $_[1] : $_[0]->{handshake} }

sub on_message { @_ > 1 ? $_[0]->{on_message} = $_[1] : $_[0]->{on_message} }

sub on_handshake {
    @_ > 1 ? $_[0]->{on_handshake} = $_[1] : $_[0]->{on_handshake};
}

sub on_response {
    @_ > 1 ? $_[0]->{on_response} = $_[1] : $_[0]->{on_response};
}

sub read {
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
            $self->on_response->($self);

            $self->write(
                $handshake->res->to_string => sub {
                    my $self = shift;

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

sub send_message {
    my $self    = shift;
    my $message = shift;

    return unless $self->handshake->is_done;

    my $frame = ReAnimator::WebSocket::Frame->new($message);
    $self->write($frame->to_string);
}

1;
