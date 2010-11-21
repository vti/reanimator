package ReAnimator::Server;

use strict;
use warnings;

use base 'ReAnimator::AtomDecorator';

sub new {
    my $self = shift->SUPER::new(@_);

    my $atom = $self->atom;
    $atom->on_read(sub { $self->parse($_[1]) });

    $self->{on_request} ||= sub { };

    return $self;
}

sub on_request {
    @_ > 1 ? $_[0]->{on_request} = $_[1] : $_[0]->{on_request};
}

sub parse {
    my $self  = shift;
    my $chunk = shift;

    my $req = $self->handshake->req;
    my $res = $self->handshake->res;

    unless ($req->is_done) {
        unless ($req->parse($chunk)) {
            $self->error($req->error);
            return;
        }

        if ($req->is_done) {
            $res->version($req->version);
            $res->host($req->host);
            #$res->secure($req->secure);
            $res->resource_name($req->resource_name);
            $res->origin($req->origin);

            if ($req->version > 75) {
                $res->number1($req->number1);
                $res->number2($req->number2);
                $res->challenge($req->challenge);
            }

            $self->on_request->($self, $self->handshake);

            $self->write(
                $res->to_string => sub {
                    my $atom = shift;

                    $self->on_handshake->($self);
                }
            );
        }

        return 1;
    }

    $self->_parse_frames($chunk);

    return 1;
}

sub send_message {
    my $self    = shift;
    my $message = shift;

    my $req = $self->handshake->req;
    unless ($req->is_done) {
        Carp::carp qq/Can't send_message, handshake is not done yet./;
        return;
    }

    $self->SUPER::send_message($message);
}

1;
