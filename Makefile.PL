#
# Author:   Rob Brown <bbb@cpan.org>
# Created:  05 Dec 2001
# $Id: Makefile.PL,v 1.7 2002/10/23 01:29:04 rob Exp $

use ExtUtils::MakeMaker;
WriteMakefile
  NAME          => 'File::DirSync',
  VERSION_FROM  => 'lib/File/DirSync.pm', # finds $VERSION
  EXE_FILES     => [ 'dirsync' ],
  PREREQ_PM	  => {
    "File::Path" => 1,
    "File::Copy" => 1,
  }, # e.g., Module::Name => 1.1
  dist => {
    COMPRESS => "gzip -9 -vf",
  },
  ;

package MY;

sub processPL {
  my $self = shift;
  my $block = $self->SUPER::processPL(@_);
  # "Version:" in spec needs to match
  # "$VERSION" from VERSION_FROM
  $block =~ s%(spec.PL\s*)$%$1 \$\(VERSION_FROM\)%m;
  $block;
}

sub libscan {
  my $self = shift;
  my $path = shift;
  ($path =~ / \bCVS\b | \~$ /x) ? undef : $path;
}

sub postamble {
  return qq^

pm_to_blib: README

README: \$(VERSION_FROM)
	pod2text \$(VERSION_FROM) > README
^;
}
