package ReAnimator::Socket;

use strict;
use warnings;

use IO::Socket;
use Errno 'EAGAIN';

use constant IO_SOCKET_SSL => eval { require IO::Socket::SSL; 1 };
use IO::Socket::SSL 'debug3';

use constant SSL_KEY => <<'EOF';
-----BEGIN PRIVATE KEY-----
MIICdgIBADANBgkqhkiG9w0BAQEFAASCAmAwggJcAgEAAoGBAMy4fNRWTlZ15y5w
yZyWN5L3POBm0K6FtXJL8WPI201fjKc5Ye55/hF4YNFIi5tF7krX9KEW1BDzZTCw
83lWAnkzpcgy4AuRPSiTWI1kINnOEtn3ae4+HYkIP9KIgVIPLHnuC5pzWBfdFBzU
UYtz+3fwnsBNFVhqJT2Iej54wPdLAgMBAAECgYEAmUNk8PLMIx6RvMrjpT8wy+4c
vUM75+xiMvd3+GRfCkYGXwsurgLWmu2sTgIpwk1QYOfcVN1qVmZh01ombShfIFaP
Y1AUrwfaBW2bgiUyOXmK3WdgycpMrhGI0KOhAWu0K5D13FOgbS6yRVNJMbDujxuE
m48qampjXZvO5jfwgoECQQDy+EWIIPvkF4fFX+VayIUceUdfz72HruVjcYjeaKEz
nSjxN3HaV3iS0n5B+Ilb+rZ0PR5XNj6mN2Pp7wx0lotzAkEA17MYD+1wyPD29fRm
alRJ8lFy8MV4UyMrOqnLX58HsmpWWHGUXb8gMSwvYqUeV3LVuDga0ucbU5KlJ5lV
y3IeyQJAeRcO4DdAEn8/pTiTv9jrrjMrRS7tkG+z1wnAYsfWfzi2LPGrBlxNtS6+
yfYpzvN2dxv2wRRByOkWHIKMvJZCzQJAI/J67hyaEULnRXInp0zIzhN43ltqhCB2
Ud5+QD9WnwtNvIuhOEZj7Q36D6yI8/X1XDAteDx/t1vXHlRVkgRA0QJATGt4aU84
NCzhfVIWR9wdMzuYkA8yaZrcUaKk3UKckxhGQOOwSFMB4HUbM9vTwz1VdFcjECWi
lOvmNA4Kx9riLA==
-----END PRIVATE KEY-----
EOF

use constant SSL_CERT => <<'EOF';
-----BEGIN CERTIFICATE-----
MIICZjCCAc+gAwIBAgIJAOfXxWTGTLcyMA0GCSqGSIb3DQEBBQUAMEwxCzAJBgNV
BAYTAkRFMRMwEQYDVQQIDApTb21lLVN0YXRlMRMwEQYDVQQKDApSZUFuaW1hdG9y
MRMwEQYDVQQDDApSZUFuaW1hdG9yMB4XDTEwMTEwNjIyMDYxMloXDTMwMTEwMTIy
MDYxMlowTDELMAkGA1UEBhMCREUxEzARBgNVBAgMClNvbWUtU3RhdGUxEzARBgNV
BAoMClJlQW5pbWF0b3IxEzARBgNVBAMMClJlQW5pbWF0b3IwgZ8wDQYJKoZIhvcN
AQEBBQADgY0AMIGJAoGBAMy4fNRWTlZ15y5wyZyWN5L3POBm0K6FtXJL8WPI201f
jKc5Ye55/hF4YNFIi5tF7krX9KEW1BDzZTCw83lWAnkzpcgy4AuRPSiTWI1kINnO
Etn3ae4+HYkIP9KIgVIPLHnuC5pzWBfdFBzUUYtz+3fwnsBNFVhqJT2Iej54wPdL
AgMBAAGjUDBOMB0GA1UdDgQWBBRPvH4ezMIfId3cqbEHnKMcPo2auzAfBgNVHSME
GDAWgBRPvH4ezMIfId3cqbEHnKMcPo2auzAMBgNVHRMEBTADAQH/MA0GCSqGSIb3
DQEBBQUAA4GBAEeySk5j1EAFkGphrKrODJG6UK/PmmDrUrFbr67cLZRwJ5qe+vGb
tpDETZXAYGvbO+ECLeTYqQoLqQN86d66PIBdWoRoBnNgd9P49GhFGOvnEZ4d8VHI
wKNBg8NajSWDIy9TVaaqrXggBTQNYNKsGiX3gDIwdooxE2dsEiYw+eE/
-----END CERTIFICATE-----
EOF

sub new {
    my $class  = shift;
    my %params = @_;

    my $self = {};
    bless $self, $class;

    $self->{secure} = 1 if delete $params{secure};

    $self->{sd} = $class->_build_server(@_)
      if $params{address} && $params{port};

    $self->{sd} ||= $class->_build_client;

    return $self;
}

sub sd     { shift->{sd} }
sub secure { shift->{secure} }

sub accept {
    my $self = shift;

    my $sd = $self->sd->accept || return;
    return ($sd) unless $self->secure;

    $sd = IO::Socket::SSL->start_SSL(
        $sd,
        SSL_startHandshake => 0,
        SSL_server         => 1,
        SSL_key_file       => 'cakey.pem',
        SSL_cert_file      => 'cacert.pem'
    ) || die $!;

    $sd->blocking(0);

    warn 'ACCEPT OK';
    unless ($sd->accept_SSL) {
        warn "SSL FAILED: $SSL_ERROR";
        return (undef, $sd) if $! == EAGAIN;
        $sd->close;
        return ();
    }
    warn 'SSL ACCEPT OK';

    return ($sd);
}

sub _build_server {
    shift;
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

sub _build_client {
    shift;

    my $socket = IO::Socket::INET->new(
        Proto    => 'tcp',
        Type     => SOCK_STREAM,
        Blocking => 0
    );

    $socket->blocking(0);

    return $socket;
}

1;
