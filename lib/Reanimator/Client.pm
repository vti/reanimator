package Reanimator::Client;

use strict;
use warnings;

use base 'Reanimator::Connection';

use Reanimator::Handshake;
use Reanimator::Frame;

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{frame}     = Reanimator::Frame->new;
    $self->{handshake} = Reanimator::Handshake->new;

    $self->{buffer} = '';

    $self->{on_connect}    ||= sub { };
    $self->{on_disconnect} ||= sub { };
    $self->{on_message}    ||= sub { };
    $self->{on_error}      ||= sub { };

    $self->state('handshake');

    return $self;
}

sub is_connected { shift->is_state('connected') }

sub connected {
    my $self = shift;

    $self->state('connected');

    $self->on_connect->($self);
}

sub read {
    my $self  = shift;
    my $chunk = shift;

    if ($self->is_state('handshake')) {
        my $handshake = $self->{handshake};

        my $rs = $handshake->parse($chunk);
        return unless defined $rs;

        if ($handshake->is_done) {
            my $res = $handshake->res->to_string;

            $self->write($res);
            $self->connected;

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

    return unless $self->is_connected;

    my $frame = Reanimator::Frame->new($message);
    $self->write($frame->to_string);
}

1;
