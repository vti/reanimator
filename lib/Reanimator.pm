package Reanimator;

use strict;
use warnings;

use Reanimator::Client;
use Reanimator::Slave;
use Reanimator::Timer;

use IO::Socket;
use IO::Poll qw/POLLIN POLLOUT POLLHUP POLLERR/;
use Errno qw/EAGAIN/;

use constant DEBUG => $ENV{DEBUG} ? 1 : 0;

our $VERSION = '0.0001';

sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $self = {@_};
    bless $self, $class;

    $self->{host} ||= 'localhost';
    $self->{port} ||= '3000';

    $self->{poll} = IO::Poll->new;

    $self->{on_connect} ||= sub { };
    $self->{on_error}   ||= sub { };

    $self->{connections} = {};
    $self->{timers}      = {};

    return $self;
}

sub on_connect { @_ > 1 ? $_[0]->{on_connect} = $_[1] : $_[0]->{on_connect} }
sub on_error   { @_ > 1 ? $_[0]->{on_error}   = $_[1] : $_[0]->{on_error} }

sub start {
    my $self = shift;

    my $host = $self->host;
    my $port = $self->port;

    $self->{server} = IO::Socket::INET->new(
        Proto       => 'tcp',
        LocalAddres => $host,
        LocalPort   => $port,
        Type        => SOCK_STREAM,
        Listen      => SOMAXCONN,
        ReuseAddr   => 1,
        Blocking    => 0
    );

    $self->server->blocking(0);

    print "Listening on $host:$port\n";

    $self->loop;
}

sub poll   { shift->{poll} }
sub server { shift->{server} }
sub host   { shift->{host} }
sub port   { shift->{port} }

sub connections { shift->{connections} }
sub timers      { shift->{timers} }

sub loop {
    my $self = shift;

    my $server = $self->server;
    while (1) {
        $self->_accept_clients;

        $self->_tick;

        $self->_timers;

        $self->_write;

        $self->_read;
    }
}

sub _accept_clients {
    my $self = shift;

    while (my $socket = $self->server->accept) {
        printf "[New client from %s]\n", $socket->peerhost;

        $self->add_client($socket);
    }
}

sub _tick {
    my $self = shift;

    $self->poll->poll(0);
}

sub _timers {
    my $self = shift;

    foreach my $id (keys %{$self->timers}) {
        my $timer = $self->timers->{$id};

        if ($timer->{timer}->elapsed) {
            $timer->{cb}->();
            delete $self->timers->{$id} if $timer->{timer}->shot;
        }
    }
}

sub _write {
    my $self = shift;

    foreach my $id (keys %{$self->connections}) {
        my $c = $self->get_connection($id);

        next unless $c->is_connected;
        next unless $c->is_writing;

        warn '> ' . $c->buffer if DEBUG;

        my $buffer = $c->buffer;
        my $br = syswrite($c->socket, $buffer, length $buffer);
        next unless defined $br;

        if ($br == 0) {
            next if $! == EAGAIN;
            $self->drop_connection($id);
            next;
        }

        $c->bytes_written($br);
    }
}

sub _read {
    my $self = shift;

    if (my @write = $self->poll->handles(POLLOUT)) {
        foreach my $socket (@write) {
            my $rb = sysread($socket, my $chunk, 1024);
            next unless defined $rb;

            if ($rb == 0) {
                next if $! == EAGAIN;

                $self->drop_connection("$socket");
                next;
            }

            warn '< ', $chunk if DEBUG;

            my $client = $self->get_connection("$socket");

            $self->drop_connection("$client")
              unless defined $client->read($chunk);
        }
    }
}

sub add_client {
    my $self   = shift;
    my $socket = shift;

    $self->_register_socket($socket);

    my $id = "$socket";

    my $client = Reanimator::Client->new(
        id         => $id,
        socket     => $socket,
        on_connect => sub {
            $self->on_connect->($self, @_);
        }
    );

    $self->connections->{$id} = $client;
}

sub add_slave {
    my $self = shift;
    my $c    = shift;

    my $socket = IO::Socket::INET->new(
        Proto => 'tcp',
        Type  => SOCK_STREAM
    );

    $socket->blocking(0);

    my $id = "$socket";

    $self->_register_socket($socket);

    $c->id($id);
    $c->socket($socket);

    $self->connections->{$id} = $c;

    my $addr = sockaddr_in($c->port, inet_aton($c->address));
    my $result = $socket->connect($addr);
}

sub set_timeout {
    my $self = shift;
    my ($interval, $cb) = @_;

    my $timer =
      Reanimator::Timer->new(interval => $interval, shot => 1);

    $self->_add_timer($timer, $cb);

    return $self;
}

sub set_interval {
    my $self = shift;
    my ($interval, $cb) = @_;

    my $timer = Reanimator::Timer->new(interval => $interval);

    $self->_add_timer($timer, $cb);

    return $self;
}

sub _add_timer {
    my $self = shift;
    my ($timer, $cb) = @_;

    $self->timers->{"$timer"} = {timer => $timer, cb => $cb};
}

sub _register_socket {
    my $self   = shift;
    my $socket = shift;

    $self->poll->mask($socket => POLLIN);
    $self->poll->mask($socket => POLLOUT);
}

sub get_connection {
    my $self = shift;
    my $id   = shift;

    return $self->connections->{$id};
}

sub drop_connection {
    my $self = shift;
    my $id   = shift;

    my $c = $self->connections->{$id};

    print "Connection closed\n";

    $self->poll->remove($c->socket);
    close $c->socket;

    delete $self->connections->{$id};
}

sub clients {
    my $self = shift;

    return map { $self->get_connection($_) } grep {
        $self->connections->{$_}->isa('Reanimator::Client')
    } keys %{$self->connections};
}

sub slaves {
    my $self = shift;

    return map { $self->get_connection($_) } grep {
        $self->connections->{$_}->isa('Reanimator::Slave:')
    } keys %{$self->connections};
}

sub send_broadcast_message {
    my $self    = shift;
    my $message = shift;

    foreach my $client ($self->clients) {
        $client->send_message($message);
    }
}

1;
