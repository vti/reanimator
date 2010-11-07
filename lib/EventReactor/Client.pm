package EventReactor::Client;

use strict;
use warnings;

use base 'EventReactor::Atom';

sub new {
    my $self = shift->SUPER::new(@_);

    $self->connected;

    return $self;
}

sub accepting    { shift->state('accepting') }
sub is_accepting { shift->is_state('accepting') }

sub is_accepted { shift->state('accepted') }

sub accepted {
    my $self = shift;

    $self->state('accepted');

    $self->on_connect->($self);

    return $self;
}

1;
