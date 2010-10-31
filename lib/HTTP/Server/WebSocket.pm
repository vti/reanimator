package HTTP::Server::WebSocket;

use strict;
use warnings;

use HTTP::Server::WebSocket::Client;

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

    $self->{clients} = {};

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

sub poll    { shift->{poll} }
sub server  { shift->{server} }
sub host    { shift->{host} }
sub port    { shift->{port} }
sub clients { shift->{clients} }

sub loop {
    my $self = shift;

    my $server = $self->server;
    while (1) {
        while (my $socket = $server->accept) {
            printf "[New client from %s]\n", $socket->peerhost;

            $self->add_client($socket);
        }

        $self->poll->poll(0);

        my $clients = $self->clients;
        foreach my $id (keys %$clients) {
            my $client = $clients->{$id};

            next unless $client->is_connected;
            next unless $client->has_data;

            warn '> ' . $client->data if DEBUG;

            my $buffer = $client->data;
            my $br = syswrite($client->socket, $buffer, length $buffer);
            next unless defined $br;

            if ($br == 0) {
                next if $! == EAGAIN;
                $self->drop_client("$client");
                next;
            }

            $client->bytes_written($br);
        }

        if (my @write = $self->poll->handles(POLLOUT)) {
            foreach my $socket (@write) {
                my $rb = sysread($socket, my $chunk, 1024);
                next unless defined $rb;

                if ($rb == 0) {
                    next if $! == EAGAIN;

                    $self->drop_client("$socket");
                    next;
                }

                warn '< ', $chunk if DEBUG;

                my $client = $self->clients->{"$socket"};

                $self->drop_client("$client")
                  unless defined $client->read($chunk);
            }
        }
    }
}

sub add_client {
    my $self   = shift;
    my $socket = shift;

    $self->poll->mask($socket => POLLIN);
    $self->poll->mask($socket => POLLOUT);

    my $client = HTTP::Server::WebSocket::Client->new(
        socket     => $socket,
        on_connect => sub {
            $self->on_connect->($self, @_);
        }
    );

    $self->clients->{"$socket"} = $client;
}

sub drop_client {
    my $self = shift;
    my $id   = shift;

    my $client = $self->clients->{$id};

    print "HTTP::Server::WebSocket::Client disconnected\n";

    $self->poll->remove($client->socket);
    close $client->socket;

    delete $self->clients->{"$client"};
}

1;
