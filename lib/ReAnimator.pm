package ReAnimator;

use strict;
use warnings;

use EventReactor;
use ReAnimator::Server;

sub new {
    my $class  = shift;
    my %params = @_;

    my $self = {};
    bless $self, $class;

    $self->{handshake_timeout} = delete $params{handshake_timeout} || 10;

    $self->{on_accept} = delete $params{on_accept};

    $self->{event_reactor} = delete $params{event_reactor}
      || $self->_build_event_reactor(%params);

    $self->event_reactor->on_accept(
        sub {
            my ($event_reactor, $atom) = @_;

            $atom->on_error(
                sub {
                    $self->drop($atom);
                }
            );

            my $conn;
            $conn = ReAnimator::Server->new(
                atom         => $atom,
                on_handshake => sub {
                    $self->{on_accept}->($self, $conn);
                }
            );
        }
    );

    return $self;
}

sub event_reactor { shift->{event_reactor} }

sub _build_event_reactor { shift; EventReactor->new(@_) }

sub handshake_timeout {
    @_ > 1 ? $_[0]->{handshake_timeout} = $_[1] : $_[0]->{handshake_timeout};
}

sub send_broadcast_message {
    my $self    = shift;
    my $message = shift;

    foreach my $atom ($self->event_reactor->accepted_atoms) {
        $atom->send_message($message);
    }
}

sub listen { shift->event_reactor->listen }
sub drop   { shift->event_reactor->drop(@_) }

1;
