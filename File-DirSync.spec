# Automatically generated by File-DirSync.spec.PL
%define perlmod File-DirSync
Summary:	%{perlmod} perl module
Name:		perl-%{perlmod}
Version:	1.03
Release:	1
License:	GPL
Group:		Development/Languages/Perl
Source0:	http://www.cpan.org./authors/id/B/BB/BBB/%{perlmod}-%{version}.tar.gz
Packager:	Rob Brown <rob@roobik.com>
Prefix: 	/usr
BuildRequires:	perl
Requires:	perl
BuildRoot:	/var/tmp/%{name}-%{version}-root
Provides:	%{perlmod}

%description
%{perlmod} Perl Module

%prep
%setup -q -n %{perlmod}-%{version}

%build
perl Makefile.PL
make
make test

%install
rm -rf $RPM_BUILD_ROOT
make PREFIX=$RPM_BUILD_ROOT%{prefix} install
find $RPM_BUILD_ROOT%{prefix} -type f -print | perl -p -e "s@^$RPM_BUILD_ROOT(.*)@\$1*@g" | grep -v perllocal.pod | grep -v packlist > %{name}-filelist

%clean
rm -rf $RPM_BUILD_ROOT

%files -f %{name}-filelist
%defattr(-,root,root)

%post

%changelog
* Wed Dec 12 2001 Rob Brown <rob@roobik.com>
- initial creation
