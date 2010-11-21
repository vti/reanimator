package ReAnimator::Client;

use strict;
use warnings;

use base 'ReAnimator::AtomDecorator';

use ReAnimator::WebSocket::URL;

sub new {
    my $self = shift->SUPER::new(@_);

    my $url = $self->{url};
    $url = ReAnimator::WebSocket::URL->new->parse($url) unless ref $url;

    my $req = $self->handshake->req;

    my $host = $url->host;
    $host .= ':' . $url->port if defined $url->port;
    $req->host($host);

    $req->resource_name($url->resource_name);

    my $atom = $self->atom;
    $atom->write(
        $req->to_string => sub {
            $atom->on_read(sub { $self->parse($_[1]) });
        }
    );

    $self->{on_response} ||= sub { };

    return $self;
}

sub on_response {
    @_ > 1 ? $_[0]->{on_response} = $_[1] : $_[0]->{on_response};
}

sub parse {
    my $self  = shift;
    my $chunk = shift;

    my $req = $self->handshake->req;
    my $res = $self->handshake->res;

    unless ($res->is_done) {
        unless ($res->parse($chunk)) {
            $self->error($res->error);
            return;
        }

        if ($res->is_done) {

            if ($req->version > 75 && $req->checksum ne $res->checksum) {
                warn 'CHECKSUM IS WRONG!';
                $self->error('Checksum is wrong');
                return;
            }

            #$self->on_request->($self, $self->handshake);

            $self->on_handshake->($self);
        }

        return 1;
    }

    $self->_parse_frames($chunk);

    return 1;
}

sub send_message {
    my $self    = shift;
    my $message = shift;

    my $res = $self->handshake->res;
    unless ($res->is_done) {
        Carp::carp qq/Can't send_message, handshake is not done yet./;
        return;
    }

    $self->SUPER::send_message($message);
}

1;
