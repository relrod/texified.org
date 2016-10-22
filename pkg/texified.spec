%global gitdate 20161022
%global buildhost %(hostname)

Name:           texified
Version:        1
Release:        1.%{gitdate}git%{?dist}
Summary:        The "texified.org" webapp.
License:        BSD
URL:            https://github.com/relrod/texified.org
BuildRequires:  git ghc systemd chrpath

# This is disabled for my local builds, since I use cabal from git.
%if "%{buildhost}" != "t520.home.elrod.me"
BuildRequires: cabal-install >= 1.18
%endif

%description
texified.org

%prep
if [ -d texified.org ]; then
  cd texified.org
  git reset --hard && git pull
else
  git clone git://github.com/relrod/texified.org/
  cd texified.org
fi

%build
export LANG=en_US.UTF-8
cd texified.org
cabal sandbox init
cabal install -j --only-dependencies
cabal install -j

%check

%install
mkdir -p %{buildroot}/%{_bindir}
cd texified.org
cp .cabal-sandbox/bin/%{name} %{buildroot}/%{_bindir}/%{name}
chrpath --delete %{buildroot}/%{_bindir}/%{name}

# systemd
mkdir -p %{buildroot}/%{_unitdir}
cp pkg/%{name}.service %{buildroot}/%{_unitdir}/%{name}.service

# database
mkdir -p %{buildroot}/%{_datarootdir}/%{name}
chown -R nobody.nobody %{buildroot}/%{_datarootdir}/%{name}

%files
%{_unitdir}/%{name}.service
%{_bindir}/%{name}

%changelog
* Sat Oct 22 2016 Ricky Elrod <ricky@elrod.me> - 1-1.20161022git
- Deploy
