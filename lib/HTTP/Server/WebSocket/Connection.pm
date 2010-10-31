package HTTP::Server::WebSocket::Connection;

use strict;
use warnings;

use base 'HTTP::Server::WebSocket::Stateful';

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{on_message} ||= sub {};

    return $self;
}

sub id     { @_ > 1 ? $_[0]->{id}     = $_[1] : $_[0]->{id} }
sub socket { @_ > 1 ? $_[0]->{socket} = $_[1] : $_[0]->{socket} }

sub on_connect { @_ > 1 ? $_[0]->{on_connect} = $_[1] : $_[0]->{on_connect} }

sub on_disconnect {
    @_ > 1 ? $_[0]->{on_disconnect} = $_[1] : $_[0]->{on_disconnect};
}
sub on_message { @_ > 1 ? $_[0]->{on_message} = $_[1] : $_[0]->{on_message} }
sub on_error   { @_ > 1 ? $_[0]->{on_error}   = $_[1] : $_[0]->{on_error} }

sub is_connected { shift->socket->connected }

sub read {
    my $self  = shift;
    my $chunk = shift;

    $self->on_message->($self, $chunk);

    return 1;
}

sub write {
    my $self  = shift;
    my $chunk = shift;

    $self->{buffer} .= $chunk;
}

sub is_writing {
    my $self = shift;

    return length $self->{buffer} ? 1 : 0;
}

sub buffer { shift->{buffer} }

sub bytes_written {
    my $self  = shift;
    my $count = shift;

    substr $self->{buffer}, 0, $count, '';

    return $self;
}
1;
