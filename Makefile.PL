#
# Author:   Rob Brown <rob@roobik.com>
# Created:  05 Dec 2001
# $Id: Makefile.PL,v 1.3 2001/12/12 19:37:50 rob Exp $

use ExtUtils::MakeMaker;
WriteMakefile
  NAME          => 'File::DirSync',
  EXE_FILES     => [ 'dirsync' ],
  VERSION_FROM  => 'DirSync.pm', # finds $VERSION
  clean => {
    FILES => q[*.bak *~ *.spec],
  },
  PREREQ_PM	  => {
    "File::Path" => 1,
    "File::Copy" => 1,
  }, # e.g., Module::Name => 1.1
;

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
