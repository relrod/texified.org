%global gitdate 20170913
%global buildhost %(hostname)

Name:           texified
Version:        1
Release:        1.%{gitdate}git%{?dist}
Summary:        The "texified.org" webapp.
License:        BSD
URL:            https://github.com/relrod/texified.org
BuildRequires:  git ghc systemd chrpath

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

# This is a hack for now until I figure out a better way to deploy, or forego
# making the config a Haskell module and switch to a stringy thing instead:
cp /home/ricky/devel/haskell/texified/src/TexifiedConfig.hs src/

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
* Wed Sep 13 2017 Ricky Elrod <ricky@elrod.me> - 1.1.20170913git
- Deploy

* Sat Oct 22 2016 Ricky Elrod <ricky@elrod.me> - 1-1.20161022git
- Deploy
