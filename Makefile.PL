#
# Author:   Rob Brown <rob@roobik.com>
# Created:  05 Dec 2001
# $Id: Makefile.PL,v 1.2 2001/12/05 22:29:28 rob Exp $

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME          => 'File::DirSync',
    EXE_FILES     => [ 'dirsync' ],
    VERSION_FROM  => 'DirSync.pm', # finds $VERSION
    PREREQ_PM	  => {
      "File::Path" => 1,
      "File::Copy" => 1,
    }, # e.g., Module::Name => 1.1
);

package MY;

sub libscan {
  my $self = shift;
  my $path = shift;
  ($path =~ / \bCVS\b | \~$ /x) ? undef : $path;
}

sub postamble {
  return qq^

pm_to_blib: README

README: DirSync.pm
\tpod2text DirSync.pm >README
  ^;
}
