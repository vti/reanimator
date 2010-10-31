package HTTP::Server::WebSocket::Response;

use strict;
use warnings;

sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub origin { @_ > 1 ? $_[0]->{sec_origin} = $_[1] : $_[0]->{sec_origin} }
sub host { @_ > 1 ? $_[0]->{sec_host} = $_[1] : $_[0]->{sec_host} }
sub path { @_ > 1 ? $_[0]->{sec_path} = $_[1] : $_[0]->{sec_path} }

sub checksum { @_ > 1 ? $_[0]->{checksum} = $_[1] : $_[0]->{checksum} }

sub to_string {
    my $self = shift;

    my $string = '';

    $string .= "HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a";

    $string .= "Upgrade: WebSocket\x0d\x0a";
    $string .= "Connection: Upgrade\x0d\x0a";

    $string .= 'Sec-WebSocket-Origin: ' . $self->origin . "\x0d\x0a";

    my $host = $self->host;
    $host =~ s/^https?:\/\///;
    my $location = 'ws://' . $host . $self->path;
    $string .= 'Sec-WebSocket-Location: ' . $location . "\x0d\x0a";

    foreach my $name (keys %{$self->{fields}}) {
        $string .= $name . ': ' . $self->{fields}->{$name} . "\x0d\x0a";
    }

    $string .= "\x0d\x0a";

    $string .= $self->checksum;

    return $string;
}

1;
