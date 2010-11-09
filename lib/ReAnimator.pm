package ReAnimator;

use strict;
use warnings;

use base 'EventReactor';

use ReAnimator::Server;

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{handshake_timeout} ||= 10;

    return $self;
}

sub handshake_timeout {
    @_ > 1 ? $_[0]->{handshake_timeout} = $_[1] : $_[0]->{handshake_timeout};
}

sub send_broadcast_message {
    my $self    = shift;
    my $message = shift;

    foreach my $atom ($self->accepted_atoms) {
        $atom->send_message($message);
    }
}

sub _build_accepted_atom {
    my $self   = shift;
    my $socket = shift;

    my $server;
    $server = ReAnimator::Server->new(
        socket     => $socket,
        secure     => $self->secure,
        socket     => $socket,
        on_accept => sub {
            $self->set_timeout(
                $server => $self->handshake_timeout => sub {
                    return if $server->handshake->is_done;

                    $server->error('Handshake timeout.');
                    $self->drop($server);
                }
            );
        },
        on_handshake => sub {
            $self->on_accept->($self, @_);
        }
    );

    return $server;
}

1;
