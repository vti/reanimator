package ReAnimator;

use strict;
use warnings;

use ReAnimator::Client;
use ReAnimator::Socket;
use ReAnimator::Slave;
use ReAnimator::Timer;

use IO::Socket;
use IO::Poll qw/POLLIN POLLOUT POLLHUP POLLERR/;
use Errno qw/EAGAIN EWOULDBLOCK EINPROGRESS/;

use constant DEBUG => $ENV{DEBUG} ? 1 : 0;

our $VERSION = '0.0001';

$SIG{PIPE} = 'IGNORE';

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

    my $socket = ReAnimator::Socket->new($host, $port);
    die "Can't create server" unless $socket;

    $self->{server} = $socket;

    $self->poll->mask($self->server => POLLIN | POLLOUT);

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

    while (1) {
        $self->_loop_once;

        $self->_timers;

        $self->_read;

        $self->_write;
    }
}

sub _loop_once {
    my $self = shift;

    my $timeout = 0.1;

    if ($self->poll->handles) {
        $self->poll->poll($timeout);
    }
    else {
        select(undef, undef, undef, $timeout);
    }
}

sub _timers {
    my $self = shift;

    foreach my $id (keys %{$self->timers}) {
        my $timer = $self->timers->{$id};

        if ($timer->{timer}->elapsed) {
            $timer->call;
            delete $self->timers->{$id} if $timer->{timer}->oneshot;
        }
    }
}

sub _read {
    my $self = shift;

    foreach my $socket ($self->poll->handles(POLLIN | POLLERR)) {
        if ($socket == $self->server) {
            $self->add_client($socket->accept);
            next;
        }

        my $conn = $self->connection($socket);

        my $rb = sysread($socket, my $chunk, 1024);

        unless ($rb) {
            next if $! && $! == EAGAIN || $! == EWOULDBLOCK;

            $self->drop($conn);
            next;
        }

        warn '< ', $chunk if DEBUG;

        my $read = $conn->read($chunk);

        unless (defined $read) {
            $self->drop($conn);
        }
    }
}

sub _write {
    my $self = shift;

    foreach my $socket ($self->poll->handles(POLLOUT | POLLERR | POLLHUP)) {
        if ($socket == $self->server) {
            next;
        }

        my $conn = $self->connection($socket);

        if ($conn->is_connecting) {
            unless ($socket->connected) {
                $self->drop($conn);
                next;
            }

            $conn->connected;

            next unless $conn->is_writing;
        }

        warn '> ' . $conn->buffer if DEBUG;

        my $br = syswrite($conn->socket, $conn->buffer);

        unless ($br) {
            next if $! == EAGAIN || $! == EWOULDBLOCK;

            $self->drop($conn);
            next;
        }

        $conn->bytes_written($br);

        $self->poll->mask($socket => POLLIN) unless $conn->is_writing;
    }
}

sub add_client {
    my $self   = shift;
    my $socket = shift;

    printf "[New client from %s]\n", $socket->peerhost if DEBUG;

    my $client = ReAnimator::Client->new(
        socket     => $socket,
        on_connect => sub {
            $self->on_connect->($self, @_);
        }
    );

    $self->add_conn($client);

    return $self;
}

sub add_slave {
    my $self = shift;
    my $conn = shift;

    my $socket = ReAnimator::Socket->new;
    $conn->socket($socket);

    $self->add_conn($conn);

    my $ip = gethostbyname($conn->address);
    my $addr = sockaddr_in($conn->port, $ip);

        $socket->connect($addr) == 0 ? $conn->connected
      : $! == EINPROGRESS            ? $conn->connecting
      :                                $self->drop($conn);

    return $self;
}

sub add_conn {
    my $self = shift;
    my $conn = shift;

    $self->poll->mask($conn->socket => POLLIN | POLLOUT);

    $conn->on_write(
        sub { $self->poll->mask(shift->socket => POLLIN | POLLOUT) });

    $self->connections->{$conn->id} = $conn;

    return $self;
}

sub set_timeout { shift->set_interval(@_, oneshot => 1) }

sub set_interval {
    my $self     = shift;
    my $interval = shift;
    my $cb       = shift;

    my $timer = ReAnimator::Timer->new(interval => $interval, @_);

    $self->_add_timer($timer, $cb);

    return $self;
}

sub _add_timer {
    my $self = shift;
    my ($timer, $cb) = @_;

    $self->timers->{"$timer"} = {timer => $timer, cb => $cb};
}

sub connection {
    my $self = shift;
    my $id   = shift;

    $id = "$id" if ref $id;

    return $self->connections->{$id};
}

sub drop {
    my $self = shift;
    my $conn = shift;

    my $id = $conn->id;

    $self->poll->remove($conn->socket);
    close $conn->socket;

    if ($!) {
        print "Connection error: $!\n" if DEBUG;

        my $error = $!;
        undef $!;
        $conn->error($error);
    }
    else {
        print "Connection closed\n" if DEBUG;

        $conn->disconnected;
    }

    delete $self->connections->{$id};

    return $self;
}

sub clients {
    my $self = shift;

    return map { $self->connection($_) }
      grep     { $self->connections->{$_}->isa('ReAnimator::Client') }
      keys %{$self->connections};
}

sub slaves {
    my $self = shift;

    return map { $self->connection($_) }
      grep     { $self->connections->{$_}->isa('ReAnimator::Slave:') }
      keys %{$self->connections};
}

sub send_broadcast_message {
    my $self    = shift;
    my $message = shift;

    foreach my $client ($self->clients) {
        $client->send_message($message);
    }
}

1;
