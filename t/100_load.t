# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.t'

######################### We start with some black magic to print on failure.

use Test;
BEGIN { plan tests => 1; $loaded = 0}
END { ok $loaded;}

open (EXE, "<dirsync");
my $exe = "return 1;\n";
1 while (read(EXE, $exe, 4096, length $exe));
close EXE;

$loaded = eval $exe;

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):
