package ReAnimator;

use strict;
use warnings;

use base 'EventReactor';

use ReAnimator::Client;

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

    foreach my $client ($self->clients) {
        $client->send_message($message);
    }
}

sub _build_client {
    my $self   = shift;
    my $socket = shift;

    my $client;
    $client = ReAnimator::Client->new(
        socket     => $socket,
        secure     => $self->secure,
        socket     => $socket,
        on_connect => sub {
            $self->set_timeout(
                "$socket" => $self->handshake_timeout => sub {
                    return if $client->handshake->is_done;

                    $client->error('Handshake timeout.');
                    $self->drop($client);
                }
            );
        },
        on_handshake => sub {
            $self->on_connect->($self, @_);
        }
    );

    return $client;
}

1;
