use strict;
use warnings;

use Test::More;
use Test::Exception;

use FFI::Raw;
use Errno qw(EINVAL);

use ZMQ::FFI;
use ZMQ::FFI::Constants qw(ZMQ_REQ);
use ZMQ::FFI::Util qw(zmq_soname);

subtest 'socket errors' => sub {
    # get the EINVAL error string in a locale aware way
    $! = EINVAL;
    my $einval_str = "$!";

    my $ctx = ZMQ::FFI->new();

    throws_ok { $ctx->socket(-1) } qr/$einval_str/i,
        q(invalid socket type dies with EINVAL);


    my $socket = $ctx->socket(ZMQ_REQ);

    throws_ok { $socket->connect('foo') } qr/$einval_str/i,
        q(invalid endpoint dies with EINVAL);
};

subtest 'util errors' => sub {
    no warnings q/redefine/;

    local *FFI::Raw::new = sub  { die "fake error" };

    throws_ok { zmq_soname(die => 1) } qr/Could not load libzmq/,
        q(zmq_soname dies when die => 1 and FFI::Raw->new fails);

    lives_ok {
        ok !zmq_soname();
    } q(zmq_soname lives and returns undef when die => 0 and FFI::Raw->new fails);
};

subtest 'libc errors' => sub {
    no warnings q/redefine/;

    my $ffi_raw_new = \&FFI::Raw::new;

    # simulate libc not found
    local *FFI::Raw::new = sub  {
        my @args   = @_;
        my $soname = $args[1];

        if ( $soname =~ /libc/ ) {
            die "fake error";
        }
        else {
            return $ffi_raw_new->(@args);
        }
    };

    throws_ok { ZMQ::FFI->new()->socket() } qr/Could not find libc/,
        q(initializing ZMQ::FFI fails if libc can't be loaded);
};

done_testing;
