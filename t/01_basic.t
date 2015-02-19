use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;
use Shared::Hash;
use Time::HiRes ();

my @driver = ("File");
if (eval { require IO::Socket::UNIX }) {
    push @driver, "UNIX";
}

for my $driver (@driver) {

    subtest "basic_$driver" => sub {
        my $hash = Shared::Hash->new(driver => $driver);
        $hash->set(foo => 1);
        $hash->set(bar => [1]);
        $hash->set(baz => {hello => 1});
        # note: key MUST NOT a perl string...
        $hash->set(hoge => "い");
        is $hash->get("foo"), 1;
        is_deeply $hash->get("bar"), [1];
        is_deeply $hash->get("baz"), {hello => 1};
        is $hash->get("hoge"), "い";
        is $hash->get("NO"), undef;
    };

    subtest "fork_$driver" => sub {
        my $hash = Shared::Hash->new(driver => $driver);
        my $pid = do_fork {
            $hash->set(foo => 1);
            $hash->set(bar => [1]);
            $hash->set(baz => {hello => 1});
            $hash->set(hoge => "い");
        };
        waitpid $pid, 0;
        is $hash->get("foo"), 1;
        is_deeply $hash->get("bar"), [1];
        is_deeply $hash->get("baz"), {hello => 1};
        is $hash->get("hoge"), "い";
        is $hash->get("NO"), undef;
    };

    subtest "lock_$driver" => sub {
        my $hash = Shared::Hash->new(driver => $driver);
        $hash->set(foo => 0);
        my $pid = do_fork {
            $hash->lock(sub {
                my $hash = shift;
                $hash->set(foo => "lock");
                sleep 1;
                $hash->set(foo => 0);
            });
        };
        Time::HiRes::sleep(0.3);
        is $hash->get("foo"), 0 for 1..10;
        waitpid $pid, 0;
    };
}

done_testing;
