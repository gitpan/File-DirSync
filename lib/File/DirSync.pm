package File::DirSync;

use strict;
use Exporter;
use File::Path qw(rmtree);
use File::Copy qw(copy);
use Carp;

use vars qw( $VERSION @ISA );
$VERSION = '1.05';
@ISA = qw(Exporter);

sub new {
  my $class = shift;
  my $self = shift || {};
  $self->{only} ||= [];
  bless $self, $class;
  return $self;
}

sub rebuild {
  my $self = shift;
  my $dir = shift;

  croak 'Source directory must be specified: $obj->rebuild($directory)'
    unless defined $dir;

  # Remove trailing / if accidently supplied
  $dir =~ s%/$%%;
  -d $dir or
    croak 'Source must be a directory';

  if (@{ $self->{only} }) {
    foreach my $only (@{ $self->{only} }) {
      if ($only =~ /^$dir/) {
        $self->_rebuild( $only );
      } else {
        croak "$only is not a subdirectory of $dir";
      }
      local $self->{localmode} = 1;
      while ($only =~ s%/[^/]*$%% && $only =~ /^$dir/) {
        $self->_rebuild( $only );
      }
    }
  } else {
    $self->_rebuild( $dir );
  }
  print "Rebuild cache complete.\n" if $self->{verbose};
}

sub _rebuild {
  my $self = shift;
  my $dir = shift;

  # Hack to snab a scoped file handle.
  my $handle = do { local *FH; };
  return unless opendir($handle, $dir);
  my $current = (lstat $dir)[9];
  my $most_current = $current;
  my $node;
  while (defined ($node = readdir($handle))) {
    next if $node =~ /^\.\.?$/;
    next if $self->{ignore}->{$node};
    my $path = "$dir/$node";
    # Recurse into directories to make sure they
    # are updated before comparing time stamps
    !$self->{localmode} && !-l $path && -d _ && $self->_rebuild( $path );
    my $this_stamp = (lstat $path)[9];
    if ($this_stamp > $most_current) {
      print "Found a newer node [$path]\n" if $self->{verbose};
      $most_current = $this_stamp;
    }
  }
  closedir($handle);
  if ($most_current > $current) {
    print "Adjusting [$dir]...\n" if $self->{verbose};
    utime($most_current, $most_current, $dir);
  }
  return;
}

sub dirsync {
  my $self = shift;
  my $src = shift;
  my $dst = shift;
  croak 'Source and destination directories must be specified: $obj->dirsync($source_directory, $destination_directory)'
    unless (defined $src) && (defined $dst);

  # Remove trailing / if accidently supplied
  $src =~ s%/$%%;
  -d $src or
    croak 'Source must be a directory';
  # Remove trailing / if accidently supplied
  $dst =~ s%/$%%;
  my $upper_dst = $dst;
  $upper_dst =~ s%/?[^/]+$%%;
  if ($upper_dst && !-d $upper_dst) {
    croak "Destination root [$upper_dst] must exist: Aborting dirsync";
  }
  return $self->_dirsync( $src, $dst );
}

sub _dirsync {
  my $self = shift;
  my $src = shift;
  my $dst = shift;

  my $when_dst = (lstat $dst)[9];
  my $size_dst = -s _;
  my $when_src = (lstat $src)[9];
  my $size_src = -s _;

  # Symlink Check must be first because
  # I could not figure out how to preserve
  # timestamps (without root privileges).
  if (-l _) {
    # Source is a symlink
    my $point = readlink($src);
    if (-l $dst) {
      # Dest is a symlink, too
      if ($point eq (readlink $dst)) {
        # Symlinks match, nothing to do.
        return;
      }
      # Remove incorrect symlink
      print "$dst: Removing symlink\n" if $self->{verbose};
      unlink($dst) || warn "$dst: Failed to remove symlink: $!\n";
    }
    if (-d $dst) {
      # Wipe directory
      print "$dst: Removing tree\n" if $self->{verbose};
      rmtree($dst) || warn "$dst: Failed to rmtree: $!\n";
    } elsif (-e $dst) {
      # Regular file (or something else) needs to go
      print "$dst: Removing\n" if $self->{verbose};
      unlink($dst) || warn "$dst: Failed to purge: $!\n";
    }
    if (-l $dst || -e $dst) {
      warn "$dst: Still exists after wipe?!!!\n";
    }
    $point = $1 if $point =~ /^(.+)$/; # Taint
    # Point to the same place that $src points to
    print "$dst -> $point\n" if $self->{verbose};
    symlink($point, $dst) || warn "$dst: Failed to create symlink: $!\n";
    return;
  }

  if ($self->{nocache} && -d _) {
    $size_dst = -1;
  }
  # Short circuit and kick out the common case:
  # Nothing to do if the timestamp and size match
  return if defined
    ( $when_src && $when_dst && $size_src && $size_dst) &&
      $when_src == $when_dst && $size_src == $size_dst;

  # Regular File Check
  if (-f _) {
    # Source is a plain file
    if (-l $dst) {
      # Dest is a symlink
      print "$dst: Removing symlink\n" if $self->{verbose};
      unlink($dst) || warn "$dst: Failed to remove symlink: $!\n";
    } elsif (-d _) {
      # Wipe directory
      print "$dst: Removing tree\n" if $self->{verbose};
      rmtree($dst) || warn "$dst: Failed to rmtree: $!\n";
    }
    my $temp_dst = $dst;
    $temp_dst =~ s%/([^/]+)$%/.\#$1.dirsync.tmp%;
    if (copy($src, $temp_dst)) {
      if (rename $temp_dst, $dst) {
        print "$dst: Updated\n" if $self->{verbose};
      } else {
        warn "$dst: Failed to create: $!\n";
      }
    } else {
      warn "$temp_dst: Failed to copy: $!\n";
    }
    if (!-e $dst) {
      warn "$dst: Never created?!!!\n";
      return;
    }
    # Force permissions to match the source
    chmod( (stat $src)[2] & 0777, $dst) || warn "$dst: Failed to chmod: $!\n";
    # Force user and group ownership to match the source
    chown ( (stat _)[4], (stat _)[5], $dst) || warn "$dst: Failed to chown: $!\n";
    # Force timestamp to match the source.
    utime($when_src, $when_src, $dst) || warn "$dst: Failed to utime: $!\n";
    return;
  }

  # Missing Check
  if (!-e _) {
    # The source does not exist
    # The destination must also not exist
    print "$dst: Removing\n" if $self->{verbose};
    rmtree($dst) || warn "$dst: Failed to rmtree: $!\n";
    return;
  }

  # Finally, the recursive Directory Check
  if (-d _) {
    # Source is a directory
    if (-l $dst) {
      # Dest is a symlink
      print "$dst: Removing symlink\n" if $self->{verbose};
      unlink($dst) || warn "$dst: Failed to remove symlink: $!\n";
    }
    if (-f $dst) {
      # Dest is a plain file
      # It must be wiped
      print "$dst: Removing file\n" if $self->{verbose};
      unlink($dst) || warn "$dst: Failed to remove file: $!\n";
    }
    if (!-d $dst) {
      mkdir($dst, 0755) || warn "$dst: Failed to create: $!\n";
    }
    if (!-d $dst) {
      warn "$dst: Destination directory cannot exist?!!!\n";
    }
    # If nocache() was not specified, then it is okay
    # skip this directory if the timestamps match.
    if (!$self->{nocache}) {
      # (The directory sizes do not really matter.)
      # If the timestamps are the same, nothing to do
      # because rebuild() will ensure that the directory
      # timestamp is the most recent within its
      # entire descent.
      return if defined
        ( $when_src && $when_dst) &&
          $when_src == $when_dst;
    }

    print "$dst: Scanning...\n" if $self->{verbose};

    # I know the source is a directory.
    # I know the destination is also a directory
    # which has a different timestamp than the
    # source.  All nodes within both directories
    # must be scanned and updated accordingly.

    my ($handle, $node, %nodes);

    $handle = do { local *FH; };
    return unless opendir($handle, $src);
    while (defined ($node = readdir($handle))) {
      next if $node =~ /^\.\.?$/;
      next if $self->{ignore}->{$node};
      next if ($self->{localmode} &&
               !-l "$src/$node" &&
               -d _);
      $nodes{$node} = 1;
    }
    closedir($handle);

    $handle = do { local *FH; };
    return unless opendir($handle, $dst);
    while (defined ($node = readdir($handle))) {
      next if $node =~ /^\.\.?$/;
      next if $self->{ignore}->{$node};
      next if ($self->{localmode} &&
               !-l "$src/$node" &&
               -d _);
      $nodes{$node} = 1;
    }
    closedir($handle);

    # %nodes is now a union set of all nodes
    # in both the source and destination.
    # Recursively call myself for each node.
    foreach $node (keys %nodes) {
      $self->_dirsync("$src/$node", "$dst/$node");
    }
    # Force user and group ownership to match the source
    chown ( (stat $src)[4], (stat _)[5], $dst) || warn "$dst: Failed to chown: $!\n";
    # Force timestamp to match the source.
    utime($when_src, $when_src, $dst) || warn "$dst: Failed to utime: $!\n";
    return;
  }

  print "$src: Unimplemented weird type of file! Skipping...\n" if $self->{verbose};
}

sub only {
  my $self = shift;
  push (@{ $self->{only} }, @_);
}

sub ignore {
  my $self = shift;
  $self->{ignore} ||= {};
  # Load ignore into a hash
  foreach my $node (@_) {
    $self->{ignore}->{$node} = 1;
  }
}

sub lockfile {
  my $self = shift;
  my $lockfile = shift or return;
  open (LOCK, ">$lockfile") or return;
  if (!flock(LOCK, 6)) { # (LOCK_EX | LOCK_NB)
    print "Skipping due to concurrent process already running.\n" if $self->{verbose};
    exit;
  }
}

sub verbose {
  my $self = shift;
  if (@_) {
    $self->{verbose} = shift;
  }
  return $self->{verbose};
}

sub localmode {
  my $self = shift;
  if (@_) {
    $self->{localmode} = shift;
  }
  return $self->{localmode};
}

sub nocache {
  my $self = shift;
  if (@_) {
    $self->{nocache} = shift;
  }
  return $self->{nocache};
}

1;
__END__

=head1 NAME

File::DirSync - Syncronize two directories rapidly

$Id: DirSync.pm,v 1.3 2002/07/09 22:57:17 rob Exp $

=head1 SYNOPSIS

  use File::DirSync;

  my $dirsync = new File::DirSync {
    verbose => 1,
    nocache => 1,
    localmode => 1,
  };

  $dirsync->ignore("CVS");

  $dirsync->rebuild( $from );

  #  and / or

  $dirsync->dirsync( $from, $to );

=head1 DESCRIPTION

File::DirSync will make two directories exactly the same. The goal
is to perform this syncronization process as quickly as possible
with as few stats and reads and writes as possible.  It usually
can perform the syncronization process within a few milliseconds -
even for gigabytes or more of information.

Much like File::Copy::copy, one is designated as the source and the
other as the destination, but this works for directories too.  It
will ensure the entire file structure within the descent of the
destination matches that of the source.  It will copy files, update
time stamps, adjust symlinks, and remove files and directories as
required to force consistency.

The algorithm used to keep the directory structures consistent is
a dirsync cache stored within the source structure.  This cache is
stored within the timestamp information of the directory nodes.
No additional checksum files or separate status configurations
are required nor created.  So it will not affect any files or
symlinks within the source_directory nor its descent.

=head1 METHODS

=head2 new( [ { properties... } ] )

Instantiate a new object to prepare for the rebuild and/or dirsync
mirroring process.

  $dirsync = new File::DirSync;

Key/value pairs in a property hash may optionally be specified
as well if desired as demonstrated in the SYNOPSIS above.  The
default property hash is as follows:

  $dirsync = new File::DirSync {
    verbose => 0,
    nocache => 0,
    localmode => 0,
  };

=head2 rebuild( <source_directory> )

In order to run most efficiently, a source cache should be built
prior to the dirsync process.  That is what this method does.
Write access to <source_directory> is required.

  $dirsync->rebuild( $from );

This may take from a few seconds to a few minutes depending on
the number of nodes within its directory descent.  For best
performance, it is recommended to execute this rebuild on the
computer actually storing the files on its local drive.  If it
must be across NFS or other remote protocol, try to avoid
rebuilding on a machine with much latency from the machine
with the actual files, or it may take an unusually long time.

=head2 dirsync( <source_directory>, <destination_directory> )

Copy everything from <source_directory> to <destination_directory>.
Files and directories within <destination_directory> that do not
exist in <source_directory> will be removed.  New nodes put within
<source_directory> since the last dirsync() will be mirrored to
<destination_directory> retaining permission modes and timestamps.
Write access to <destination_directory> is required.
Read-only access to <source_directory> is sufficient.

  $dirsync->dirsync( $from, $to );

The rebuild() method should have been run on <source_directory>
prior to using dirsync() for maximum efficiency.  If not, then use
the nocache() setting to force dirsync() to mirror the entire
<source_directory> regardless of the dirsync source cache.

=head2 only( <source> [, <source> ...] )

If you are sure nothing has changed within source_directory
except for <source>, you can specify a file or directory
using this method.

  $dirsync->only( "$from/htdocs" );

However, the cache will still be built all the way up to the
source_directory.  This only() node must always be a subdirectory
or a file within source_directory.  This option only applies to
the rebuild() method and is ignored for the dirsync() method.
This method may be used multiple times to rebuild several nodes.
It may also be passed a list of nodes.  If this method is not
called before rebuild() is, then the entire directory structure
of source_directory and its descent will be rebuilt.

=head2 ignore( <node> )

Avoid recursing into directories named <node> within
source_directory.  It may be called multiple times to ignore
several directory names.

  $dirsync->ignore("CVS");

This method applies to both the rebuild() process and the
dirsync() process.

=head2 lockfile( <lockfile> )

If this option is used, <lockfile> will be used to
ensure that only one dirsync process is running at
a time.  If another process is concurrently running,
this process will immediately abort without doing
anything.  If <lockfile> does not exist, it will be
created.  This might be useful say for a cron that
runs dirsync every minute, but just in case it takes
longer than a minute to finish the dirsync process.
It would be a waste of resources to have multiple
simultaneous dirsync processes all attempting to
dirsync the same files.  The default is to always
dirsync.

=head2 verbose( [ <0_or_1> ] )

  $dirsync->verbose( 1 );

Read verbose setting or turn verbose off or on.
Default is off.

=head2 localmode( [ <0_or_1> ] )

Read or set local directory only mode to avoid
recursing into the directory descent.

  $dirsync->localmode( 1 );

Default is to perform the action recursively
by descending into all subdirectories of
source_directory.

=head2 nocache( [ <0_or_1> ] )

When mirroring from source_directory to destination_directory,
do not assume the rebuild() method has been run on the source
already to rebuild the dirsync cache.  All files will be
mirrored.

  $dirsync->nocache( 1 );

If enabled, it will significantly degrade the performance
of the mirroring process.  The default is 0 - assume that
rebuild() has already rebuilt the source cache.

=head1 TODO

Generalized file manipulation routines to allow for easier
integration with third-party file management systems.

Support for FTP dirsync (both source and destination).

Support for Samba style sharing dirsync.

Support for VFS, HTTP/DAV, and other more standard remote
third-party file management.

Support for skipping dirsync to avoid wiping the entire
destination directory when the source directory is empty.

Support for dereferencing symlinks instead of creating
matching symlinks in the destination.

=head1 BUGS

If the source or destination directory permission settings do not
provide write access, there may be problems trying to update nodes
within that directory.

If a source file is modified after, but within the same second, that
it is dirsynced to the destination and is exactly the same size, the
new version may not be updated to the destination.  The source will
need to be modified again or at least the timestamp changed after
the entire second has passed by.  A quick touch should do the trick.

It does not update timestamps on symlinks, because I could not
figure out how to do it without dinking with the system clock. :-/
If anyone knows a better way, just let the author know.

Only plain files, directories, and symlinks are supported at this
time.  Special files, (including mknod), pipe files, and socket files
will be ignored.

=head1 AUTHOR

Rob Brown, bbb@cpan.org

=head1 COPYRIGHT

Copyright (C) 2002, Rob Brown, bbb@cpan.org

All rights reserved.

This may be copied, modified, and distributed under the same
terms as Perl itself.

=head1 SEE ALSO

L<File::Copy(3)>,
L<perl(1)>

=cut
