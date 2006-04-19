# Just a dumb test to make sure directory timestamps are affected
# in the proper way by nodes being created and deleted within it.

use strict;
use Test;

plan tests => 17;

# Create a dummy directory
# 1
ok mkdir("testdir");

# Grab timestamp
my $m1 = (stat "testdir")[9];
# 2
ok $m1;

# Wait long enough for the the timestamp to change
# 3
ok sleep 1;
# 4
ok sleep 1;

# Try to create a node within it
# 5
ok open (TEST, ">testdir/testfile.txt");
close(TEST);

# Grab timestamp again
my $m2 = (stat "testdir")[9];
# 6
ok $m2;

# Creating a file should change the timestamp of its directory.
# 7
ok ($m2 > $m1);

# Wait some more...
# 8
ok sleep 1;
# 9
ok sleep 1;

# Try renaming the file
# 10
ok rename("testdir/testfile.txt","testdir/newfile.txt");

# Grab timestamp again
my $m3 = (stat "testdir")[9];
# 11
ok $m3;

# Renaming a file should change the timestamp of its directory.
# 12
ok ($m3 > $m2);

# Wait some more...
# 13
ok sleep 1;
# 14
ok sleep 1;

# Now wipe the file
# 15
ok unlink("testdir/newfile.txt");

# Grab timestamp again
my $m4 = (stat "testdir")[9];
# 16
ok $m4;

# Deleting a file should change the timestamp of the directory it used to be it.
# 17
ok ($m4 > $m3);

rmdir("testdir");
