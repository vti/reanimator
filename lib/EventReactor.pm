package EventReactor;

use strict;
use warnings;

use EventReactor::Atom;

#use EventReactor::Connection;
use EventReactor::Atom;
use EventReactor::Timer;
use EventReactor::Loop;

use IO::Socket;
use Errno qw/EAGAIN EWOULDBLOCK EINPROGRESS/;

use constant DEBUG => $ENV{EVENT_REACTOR_DEBUG} ? 1 : 0;

use constant IO_SOCKET_SSL => eval { require IO::Socket::SSL; 1 };

our $VERSION = '0.0001';

$SIG{PIPE} = 'IGNORE';

sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $self = {@_};
    bless $self, $class;

    $self->{max_clients} ||= 100;

    $self->{address} ||= $ENV{REANIMATOR_ADDRESS} || '0.0.0.0';
    $self->{port}    ||= $ENV{REANIMATOR_PORT}    || '3000';

    $self->{loop} = $self->_build_loop;

    $self->{on_connect} ||= sub { };
    $self->{on_error}   ||= sub { };

    $self->{atoms}  = {};
    $self->{timers} = {};

    return $self;
}

sub build_slave { shift; EventReactor::Slave->new(@_) }

sub secure { @_ > 1 ? $_[0]->{secure} = $_[1] : $_[0]->{secure} }

sub on_connect { @_ > 1 ? $_[0]->{on_connect} = $_[1] : $_[0]->{on_connect} }
sub on_error   { @_ > 1 ? $_[0]->{on_error}   = $_[1] : $_[0]->{on_error} }

sub loop    { shift->{loop} }
sub server  { shift->{server} }
sub address { shift->{address} }
sub port    { shift->{port} }

sub atoms  { shift->{atoms} }
sub timers { shift->{timers} }

sub max_clients {
    @_ > 1 ? $_[0]->{max_clients} = $_[1] : $_[0]->{max_clients};
}

sub listen {
    my $self = shift;

    if ($self->secure) {
        die 'IO::Socket::SSL is required' unless IO_SOCKET_SSL;
    }

    my $address = $self->address;
    my $port    = $self->port;

    my $socket = $self->_build_server_socket(
        address => $address,
        port    => $port
    );
    die "Can't create server" unless $socket;

    $self->{server} = $socket;

    $self->loop->mask_rw($self->server);

    print "Listening on $address:$port\n" if DEBUG;

    $self->_loop_until_i_die;
}

#sub connect {
#my $self = shift;

#my $atom   = $self->build_atom(@_);
#my $socket = $self->build_socket;
#$atom->socket($socket);

#$self->_add_atom($atom);

#my $ip = gethostbyname($conn->address);
#my $addr = sockaddr_in($conn->port, $ip);

#my $rv = $socket->connect($addr);

#if (defined $rv && $rv == 0) {
#$conn->connected;
#}
#elsif ($! == EINPROGRESS) {
#$conn->connecting;
#}
#else {
#$conn->error($!);
#$self->drop($conn);
#}

#return $conn;
#}

sub drop {
    my $self = shift;
    my $atom = shift;

    my $socket = $atom->socket;

    $self->loop->remove($socket);

    $socket->close;

    if (my $e = $atom->error) {
        print "Connection error: $e\n" if DEBUG;
    }
    else {
        print "Connection closed\n" if DEBUG;

        $atom->disconnected;
    }

    my $id = "$socket";

    delete $self->atoms->{$id};
    delete $self->timers->{$id};

    return $self;
}

sub socket {
    my $self = shift;
    my $id   = shift;

    $id = "$id" if ref $id;

    return $self->sockets->{$id};
}

sub set_timeout { shift->set_interval(@_, {one_shot => 1}) }

sub set_interval {
    my $self = shift;

    my $args     = ref $_[-1] eq 'HASH' ? pop : {};
    my $cb       = pop;
    my $id       = @_ == 2 ? shift : "$self";
    my $interval = shift;

    my $timer = $self->_build_timer(interval => $interval, cb => $cb, %$args);

    $self->_add_timer($id => $timer);

    return $self;
}

sub _loop_until_i_die {
    my $self = shift;

    while (1) {
        $self->loop->tick(0.1);

        $self->_timers;

        for ($self->loop->readers) {
            $self->_read($_);
        }

        for ($self->loop->writers) {
            $self->_write($_);
        }

        for ($self->loop->errors) {
            $self->_error($_);
        }

        for ($self->loop->hups) {
            $self->_hup($_);
        }
    }
}

sub _timers {
    my $self = shift;

    foreach my $id (keys %{$self->timers}) {
        my $timer = $self->timers->{$id};

        if ($timer->wake_up) {
            delete $self->timers->{$id} if $timer->one_shot;
        }
    }
}

sub _accept {
    my $self = shift;
    my $atom = shift;

    if (!$atom) {
        my $socket = $self->server->accept;
        return unless $socket;

        my $id = "$socket";

        print "New connection\n" if DEBUG;

        $atom = $self->_build_atom($socket);
        $atom->on_write(sub { $self->loop->mask_rw($atom->socket) });

        unless ($self->secure) {
            $self->atoms->{"$socket"} = $atom;

            $self->loop->mask_rw($atom->socket);
            return $atom->accepted;
        }

        $socket = IO::Socket::SSL->start_SSL(
            $socket,
            SSL_startHandshake => 0,
            SSL_server         => 1,
            SSL_key_file       => 'cakey.pem',
            SSL_cert_file      => 'cacert.pem',
        ) || die $!;

        $socket->blocking(0);

        $self->atoms->{"$socket"} = $atom;

        if ($socket->accept_SSL) {
            $self->loop->mask_rw($atom->socket);
            return $atom->accepted;
        }
        elsif ($! && $! == EAGAIN) {
            $self->loop->mask_ro($socket);
            return;
        }
    }
    else {
        my $socket = $atom->socket;

        $atom->{socket} = $socket;
        return $atom->accepted if $socket->accept_SSL;
        return if $! && $! != EAGAIN;
    }

    $self->drop($atom);
}

sub _read {
    my $self   = shift;
    my $socket = shift;

    return $self->_accept if $socket == $self->server;

    my $atom = $self->atoms->{"$socket"};
    return unless $atom;

    return $self->_accept($atom) if $atom->is_accepting;

    my $rb = $atom->socket->sysread(my $chunk, 1024 * 4096);

    unless ($rb) {
        return if $! && $! == EAGAIN || $! == EWOULDBLOCK;

        $atom->error($!) if $!;
        return $self->drop($atom);
    }

    warn '< ', $chunk if DEBUG;

    my $read = $atom->read($chunk);

    unless (defined $read) {
        $self->drop($atom);
    }
}

sub _write {
    my $self   = shift;
    my $socket = shift;

    return $self->_accept if $socket == $self->server;

    my $atom = $self->atoms->{"$socket"};
    return unless $atom;

    return $self->_accept($atom) if $atom->is_accepting;

    if ($atom->is_connecting) {
        unless ($socket->connected) {
            $self->error($!) if $!;
            return $self->drop($atom);
        }

        $atom->connected;
    }

    return $self->loop->mask_ro($atom->socket) unless $atom->is_writing;

    warn '> ' . $atom->buffer if DEBUG;

    my $br = $atom->socket->syswrite($atom->buffer);

    if (not defined $br) {
        return if $! == EAGAIN || $! == EWOULDBLOCK;

        $atom->error($!);
        return $self->drop($atom);
    }

    return $self->drop($atom) if $br == 0;

    $atom->bytes_written($br);

    $self->loop->mask_ro($atom->socket) unless $atom->is_writing;
}

sub _error {
    my $self   = shift;
    my $socket = shift;

    my $atom = $self->atoms->{"$socket"};
    return unless $atom;

    $atom->error($!);
    return $self->drop($atom);
}

sub _hup {
    my $self   = shift;
    my $socket = shift;

    my $atom = $self->atoms->{"$socket"};
    return unless $atom;

    return $self->drop($atom);
}

sub _add_timer {
    my $self  = shift;
    my $id    = shift;
    my $timer = shift;

    die 'Unknown timer id'
      unless $self->server eq $id || exists $self->atoms->{$id};

    $self->timers->{$id} = $timer;
}

sub _build_loop { EventReactor::Loop->build }
sub _build_timer { shift; EventReactor::Timer->new(@_) }

sub _build_server_socket {
    my $self   = shift;
    my %params = @_;

    my $socket = IO::Socket::INET->new(
        Proto        => 'tcp',
        LocalAddress => $params{address},
        LocalPort    => $params{port},
        Type         => SOCK_STREAM,
        Listen       => SOMAXCONN,
        ReuseAddr    => 1,
        Blocking     => 0
    );

    $socket->blocking(0);

    return $socket;
}

sub _build_atom {
    my $self   = shift;
    my $socket = shift;

    return EventReactor::Atom->new(
        socket     => $socket,
        on_connect => sub {
            $self->on_connect($self);
        }
    );
}

1;
