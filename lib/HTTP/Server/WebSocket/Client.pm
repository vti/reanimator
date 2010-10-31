package HTTP::Server::WebSocket::Client;

use strict;
use warnings;

use base 'HTTP::Server::WebSocket::Stateful';

use HTTP::Server::WebSocket::Handshake;
use HTTP::Server::WebSocket::Frame;

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{frame}     = HTTP::Server::WebSocket::Frame->new;
    $self->{handshake} = HTTP::Server::WebSocket::Handshake->new;

    $self->{buffer} = '';

    $self->{on_connect}    ||= sub { };
    $self->{on_disconnect} ||= sub { };
    $self->{on_message}    ||= sub { };
    $self->{on_error}      ||= sub { };

    $self->state('handshake');

    return $self;
}

sub socket { @_ > 1 ? $_[0]->{socket} = $_[1] : $_[0]->{socket} }

sub on_connect { @_ > 1 ? $_[0]->{on_connect} = $_[1] : $_[0]->{on_connect} }

sub on_disconnect {
    @_ > 1 ? $_[0]->{on_disconnect} = $_[1] : $_[0]->{on_disconnect};
}
sub on_message { @_ > 1 ? $_[0]->{on_message} = $_[1] : $_[0]->{on_message} }
sub on_error   { @_ > 1 ? $_[0]->{on_error}   = $_[1] : $_[0]->{on_error} }

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

sub write {
    my $self  = shift;
    my $chunk = shift;

    $self->{buffer} .= $chunk;
}

sub has_data {
    my $self = shift;

    return length $self->{buffer} ? 1 : 0;
}

sub data { shift->{buffer} }

sub bytes_written {
    my $self  = shift;
    my $count = shift;

    substr $self->{buffer}, 0, $count, '';

    return $self;
}

sub send_message {
    my $self    = shift;
    my $message = shift;

    return unless $self->is_connected;

    my $frame = HTTP::Server::WebSocket::Frame->new($message);
    $self->write($frame->to_string);
}

1;
