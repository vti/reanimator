package ReAnimator::WebSocket::Response;

use strict;
use warnings;

use ReAnimator::WebSocket::URL;
use ReAnimator::WebSocket::Cookie::Response;

use Digest::MD5 'md5';

use base 'ReAnimator::WebSocket::Message';

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{cookies} ||= [];

    $self->{max_response_size} ||= 2048;

    $self->state('response_line');

    return $self;
}

sub challenge { @_ > 1 ? $_[0]->{challenge} = $_[1] : $_[0]->{challenge} }

sub origin {
    my $self = shift;

    return $self->{fields}->{'Sec-WebSocket-Origin'} unless @_;

    $self->{fields}->{'Sec-WebSocket-Origin'} = shift;

    return $self;
}

sub location {
    my $self = shift;

    return $self->{fields}->{'Sec-WebSocket-Location'} unless @_;

    $self->{fields}->{'Sec-WebSocket-Location'} = shift;

    return $self;
}

sub host   { @_ > 1 ? $_[0]->{host}   = $_[1] : $_[0]->{host} }
sub secure { @_ > 1 ? $_[0]->{secure} = $_[1] : $_[0]->{secure} }

sub resource_name {
    @_ > 1 ? $_[0]->{resource_name} = $_[1] : $_[0]->{resource_name};
}

sub checksum { @_ > 1 ? $_[0]->{checksum} = $_[1] : $_[0]->{checksum} }

sub cookies { @_ > 1 ? $_[0]->{cookies} = $_[1] : $_[0]->{cookies} }

sub cookie {
    my $self = shift;

    push @{$self->{cookies}},
      ReAnimator::WebSocket::Cookie::Response->new(@_);
}

sub parse {
    my $self  = shift;
    my $chunk = shift;

    return 1 unless length $chunk;

    return if $self->error;

    $self->{buffer} .= $chunk;
    $chunk = $self->{buffer};

    if (length $chunk > $self->{max_response_size}) {
        $self->error('Request is too big');
        return;
    }

    while ($chunk =~ s/^(.*?)\x0d\x0a//) {
        my $line = $1;

        if ($self->state eq 'response_line') {
            unless ($line eq 'HTTP/1.1 101 WebSocket Protocol Handshake') {
                $self->error('Wrong response line');
                return;
            }

            $self->state('fields');
        }
        elsif ($line ne '') {
            my ($name, $value) = split ': ' => $line => 2;

            $self->fields->{$name} = $value;
        }
        else {
            $self->state('body');
        }
    }

    if ($self->state eq 'body') {

        if ($self->origin && $self->location) {
            return 1 if length $chunk < 16;

            if (length $chunk > 16) {
                $self->error('Body is too long');
                return;
            }

            $self->version(76);
            $self->challenge($chunk);
        }
        else {
            $self->version(75);
        }

        return $self->done if $self->finalize;

        $self->error('Not a valid response');
        return;
    }

    return 1;
}

sub finalize {
    my $self = shift;

    my $challenge = $self->challenge;

    my $expected = '';
    $expected .= pack 'N' => $self->{number1};
    $expected .= pack 'N' => $self->{number2};
    $expected .= $self->{key3};
    $expected = md5 $expected;
    return unless $challenge eq $expected;

    my $url = ReAnimator::WebSocket::URL->new;
    return unless $url->parse($self->location);

    $self->secure($url->secure);
    $self->host($url->host);
    $self->resource_name($url->resource_name);

    return 1;
}

sub to_string {
    my $self = shift;

    my $string = '';

    $string .= "HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a";

    $string .= "Upgrade: WebSocket\x0d\x0a";
    $string .= "Connection: Upgrade\x0d\x0a";

    if ($self->version > 75) {
        my $location = ReAnimator::WebSocket::URL->new(
            host          => $self->host,
            secure        => $self->secure,
            resource_name => $self->resource_name,
        );

        $string .= 'Sec-WebSocket-Origin: ' . $self->origin . "\x0d\x0a";
        $string .= 'Sec-WebSocket-Location: ' . $location->to_string . "\x0d\x0a";
    }

    if (@{$self->cookies}) {
        $string .= 'Set-Cookie: ';
        $string .= join ',' => $_->to_string for @{$self->cookies};
        $string .= "\x0d\x0a";
    }

    $string .= "\x0d\x0a";

    $string .= $self->checksum if $self->version > 75;

    return $string;
}

1;
