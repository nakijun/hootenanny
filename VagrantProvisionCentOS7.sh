#!/usr/bin/env bash

#TODO: Fix HOOT_HOME
HOOT_HOME=$HOME/hoot
echo HOOT_HOME: $HOOT_HOME
cd ~
source ~/.bash_profile

# Keep VagrantBuild.sh happy
#ln -s ~/.bash_profile ~/.profile

# add EPEL repo for extra packages
echo "### Add epel repo ###" > CentOS_upgrade.txt
sudo yum -y install epel-release >> CentOS_upgrade.txt 2>&1

# add the Postgres repo
echo "### Add Postgres repo ###" > CentOS_upgrade.txt
sudo rpm -Uvh http://yum.postgresql.org/9.5/redhat/rhel-7-x86_64/pgdg-centos95-9.5-3.noarch.rpm >> CentOS_upgrade.txt 2>&1

echo "Updating OS..."
echo "### Update ###" >> CentOS_upgrade.txt
sudo yum -q -y update >> CentOS_upgrade.txt 2>&1
echo "### Upgrade ###" >> CentOS_upgrade.txt
sudo yum -q -y upgrade >> CentOS_upgrade.txt 2>&1

echo "### Setup NTP..."
sudo yum -q -y install ntp
sudo chkconfig ntpd on
#TODO: Better way to do this?
sudo systemctl stop ntpd
sudo ntpd -gq
sudo systemctl start ntpd


# Install Java8
# Make sure that we are in ~ before trying to wget & install stuff
cd ~
if  ! rpm -qa | grep jdk-8u111-linux; then
    echo "### Installing Java8..."
    if [ ! -f jdk-8u111-linux-x64.rpm ]; then
      JDKURL=http://download.oracle.com/otn-pub/java/jdk/8u111-b14/jdk-8u111-linux-x64.rpm
      wget --quiet --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" $JDKURL
    fi
    sudo yum -y install ./jdk-8u111-linux-x64.rpm
fi


# install useful and needed packages for working with hootenanny
echo "### Installing dependencies from repos..."
sudo yum -y install \
    automake \
    autoconf \
    boost-devel \
    ccache \
    gcc \
    gcc-c++ \
    cppunit-devel \
    gdb \
    git \
    git-core \
    geos-devel \
    libtool \
    m4 \
    nodejs \
    nodejs-devel \
    npm \
    qt \
    qt-common \
    qt-devel \
    postgis2_95 \
    postgresql95 \
    postgresql95-contrib \
    postgresql95-devel \
    postgresql95-server \
    proj \
    proj-devel \
    stxxl \
    stxxl-devel \
    python  \
    python-devel \
    python-matplotlib \
    python-pip  \
    python-setuptools \
    opencv \
    opencv-core \
    opencv-devel \
    opencv-python \
    protobuf \
    protobuf-compiler \
    protobuf-devel \
    libicu-devel \
    maven \
    glpk \
    glpk-devel \
    v8 \
    v8-devel \




echo "##### Temp installs #####"
sudo yum -y install \
    gdal \
    gdal-devel \
    gdal-python \



echo "### Configureing Postgres..."
# Need to figure out a way to do this automagically
#PG_VERSION=$(sudo -u postgres psql -c 'SHOW SERVER_VERSION;' | egrep -o '[0-9]{1,}\.[0-9]{1,}'); do
PG_VERSION=9.5

cd /tmp # Stop postgres "could not change directory to" warnings

# Postgresql startup
sudo /usr/pgsql-$PG_VERSION/bin/postgresql95-setup initdb
sudo systemctl start postgresql-$PG_VERSION
sudo systemctl enable postgresql-$PG_VERSION

if ! sudo -u postgres psql -lqt | grep -i --quiet hoot; then
    echo "### Creating Services Database..."
    sudo -u postgres createuser --superuser hoot
    sudo -u postgres psql -c "alter user hoot with password 'hoottest';"
    sudo -u postgres createdb hoot --owner=hoot
    sudo -u postgres createdb wfsstoredb --owner=hoot
    sudo -u postgres psql -d hoot -c 'create extension hstore;'
    sudo -u postgres psql -d postgres -c "UPDATE pg_database SET datistemplate='true' WHERE datname='wfsstoredb'" > /dev/null
    sudo -u postgres psql -d wfsstoredb -c 'create extension postgis;' > /dev/null
    sudo -u postgres psql -d wfsstoredb -c "GRANT ALL on geometry_columns TO PUBLIC;"
    sudo -u postgres psql -d wfsstoredb -c "GRANT ALL on geography_columns TO PUBLIC;"
    sudo -u postgres psql -d wfsstoredb -c "GRANT ALL on spatial_ref_sys TO PUBLIC;"
fi

# configure Postgres settings
PG_HB_CONF=/var/lib/pgsql/$PG_VERSION/data/pg_hba.conf
if ! sudo grep -i --quiet hoot $PG_HB_CONF; then
    sudo -u postgres cp $PG_HB_CONF $PG_HB_CONF.orig
    sudo -u postgres sed -i '1ihost    all            hoot            127.0.0.1/32            md5' $PG_HB_CONF
    sudo -u postgres sed -i '1ihost    all            hoot            ::1/128                 md5' $PG_HB_CONF
fi
POSTGRES_CONF=/var/lib/pgsql/$PG_VERSION/data/postgresql.conf
if ! grep -i --quiet HOOT $POSTGRES_CONF; then
    sudo -u postgres cp $POSTGRES_CONF $POSTGRES_CONF.orig
    sudo -u postgres sed -i s/^max_connections/\#max_connections/ $POSTGRES_CONF
    sudo -u postgres sed -i s/^shared_buffers/\#shared_buffers/ $POSTGRES_CONF
    sudo -u postgres bash -c "cat >> $POSTGRES_CONF" <<EOT
#--------------
# Hoot Settings
#--------------
max_connections = 1000
shared_buffers = 1024MB
max_files_per_process = 1000
work_mem = 16MB
maintenance_work_mem = 256MB
#checkpoint_segments = 20
autovacuum = off
EOT
fi

# configure kernel parameters
SYSCTL_CONF=/etc/sysctl.conf
if ! grep --quiet 1173741824 $SYSCTL_CONF; then
    sudo cp $SYSCTL_CONF $SYSCTL_CONF.orig
    echo "Setting kernel.shmmax"
    sudo sysctl -w kernel.shmmax=1173741824
    sudo sh -c "echo 'kernel.shmmax=1173741824' >> $SYSCTL_CONF"
    #                 kernel.shmmax=68719476736
fi
if ! grep --quiet 2097152 $SYSCTL_CONF; then
    echo "Setting kernel.shmall"
    sudo sysctl -w kernel.shmall=2097152
    sudo sh -c "echo 'kernel.shmall=2097152' >> $SYSCTL_CONF"
    #                 kernel.shmall=4294967296
fi
sudo systemctl restart postgresql-$PG_VERSION

cd ~

if ! mocha --version &>/dev/null; then
    echo "### Installing mocha for plugins test..."
    npm
    sudo npm install --silent -g mocha
    # Clean up after the npm install
    sudo rm -rf $HOME/tmp
fi



exit

# From RPM Job
    apache-maven \
      CharLS-devel \
      ImageMagick \
      ant \
      apr-devel \
      apr-util-devel \
      armadillo-devel \
      bison \
      cairo-devel \
      cfitsio-devel \
      chrpath \
      cppunit-devel \
      createrepo \
      ctags \
      curl-devel \
      doxygen \
      emacs \
      emacs \
      emacs-el \
      erlang \
      erlang \
      expat-devel \
      flex \
      fontconfig-devel \
      freexl-devel \
      g2clib-static \
      gd-devel \
      geos-devel \
      giflib-devel \
      giflib-devel \
      graphviz \
      hdf-devel \
      hdf-static \
      hdf5-devel \
      help2man \
      info \
      libX11-devel \
      libXrandr-devel \
      libXrender-devel \
      libXt-devel \
      libdap-devel \
      libdrm-devel \
      libgta-devel \
      libicu-devel \
      libjpeg-turbo-devel \
      libotf \
      libpng-devel \
      librx-devel \
      libspatialite-devel \
      libtool \
      libxslt \
      libxslt \
      lua-devel \
      m17n-lib* \
      m4 \
      mysql-devel \
      netcdf-devel \
      numpy \
      pango-devel \
      pcre-devel \
      php-devel \
      poppler-devel \
      proj-devel \
      pygtk2 \
      python-argparse \
      python-devel \
      python-devel \
      readline-devel \
      rpm-build \
      rpm-build \
      ruby \
      ruby-devel \
      sqlite-devel \
      swig \
      tetex-tex4ht \
      tex* \
      transfig \
      unixODBC-devel \
      w3m \
      wget \
      words \
      xerces-c-devel \
      xz-devel \
      zlib-devel \



exit

# install useful and needed packages for working with hootenanny
echo "### Installing dependencies from repos..."
sudo yum -y install \
 asciidoc  \
 automake  \
 boost-devel  \
 ccache  \
 cppunit-devel  \
 curl  \
 dblatex \
 doxygen  \
 fontconfig-devel  \
 freetype-devel  \
 gcc-c++  \
 gdal-devel \
 gdb  \
 geos-devel  \
 gettext  \
 git  \
 git-core  \
 glpk-devel  \
 gnuplot  \
 graphviz  \
 htop  \
 java  \
 lcov  \
 libX11-devel \
 libpng-devel \
 libtool  \
 libxslt  \
 liquibase  \
 log4cxx-devel \
 maven  \
 nodejs-devel \
 npm  \
 ogdi-devel  \
 opencv-devel  \
 openssh-server  \
 patch  \
 pgadmin3  \
 poppler  \
 postgis2_95 \
 postgresql95 \
 postgresql95-contrib \
 postgresql95-devel \
 postgresql95-server \
 proj-devel  \
 protobuf-compiler  \
 protobuf-devel  \
 python  \
 python-devel \
 python-matplotlib \
 python-pip  \
 python-setuptools \
 qt-devel  \
 ruby  \
 ruby-devel  \
 source-highlight  \
 swig  \
 texinfo-tex  \
 texlive-arabxetex  \
 texlive-collection-langcyrillic  \
 unzip  \
 w3m  \
 wget  \
 words  \
 x11vnc  \
 xerces-c  \
 xorg-x11-server-Xvfb  \
 zlib-devel  \
 >> CentOS_upgrade.txt 2>&1


# Orig List
#  asciidoc  \
#  automake  \
#  boost-devel  \
#  ccache  \
#  cppunit-devel  \
#  curl  \
#  dblatex \
#  doxygen  \
#  fontconfig-devel  \
#  freetype-devel  \
#  gcc-c++  \
#  gdal-devel \
#  gdb  \
#  gettext  \
#  git  \
#  git-core  \
#  glpk-devel  \
#  gnuplot  \
#  graphviz  \
#  htop  \
#  java-1.8.0-openjdk  \
#  java-1.8.0-openjdk-debug  \
#  lcov  \
#  libX11-devel \
#  libicu-devel  \
#  libpng  \
#  libpng-devel \
#  libtool  \
#  libxslt  \
#  liquibase  \
#  log4cxx-devel \
#  maven  \
#  nodejs-devel \
#  npm  \
#  ogdi-devel  \
#  opencv-devel  \
#  openssh-server  \
#  patch  \
#  pgadmin3  \
#  poppler  \
#  postgis  \
#  postgresql \
#  postgresql-contrib \
#  postgresql-devel  \
#  postgresql-libs  \
#  postgresql-server  \
#  proj-devel  \
#  protobuf-compiler  \
#  protobuf-devel  \
#  python  \
#  python-devel \
#  python-matplotlib \
#  python-pip  \
#  python-setuptools \
#  qt-devel  \
#  qt5-qtwebkit-devel  \
#  ruby  \
#  ruby-devel  \
#  source-highlight  \
#  swig  \
#  texinfo-tex  \
#  texlive-arabxetex  \
#  texlive-collection-langcyrillic  \
#  tomcat  \
#  unzip  \
#  w3m  \
#  wget  \
#  words  \
#  x11vnc  \
#  xerces-c  \
#  xorg-x11-server-Xvfb  \
#  zlib-devel  \

# TODO: Investigate these packages from the Ubuntu14.04 provisioning
#libcv
#newmat
#libproj-dev
#libqt4-sql-psql
#libjson-spirit-dev
#libstxll-dev
#nodejs-legacy
#geos-devel
#libboost-all-dev
#texlive-lang-hebrew
#libqt4-sql-sqlite
#postgresql-client-9.5
#postgresql-9.5-postgis-scripts 
#postgresql-client-9.5
#gdal-devel \
#stxxl-devel \

# TODO: Investigate the necessity of these
#texlive-arabxetex \
#texlive-collection-langcyrillic \


# Configure Java
if ! grep --quiet "export JAVA_HOME" ~/.bash_profile; then
    echo "Adding Java home to profile..."
    export JAVA_HOME=/usr/java/jdk1.8.0_111 >> ~/.bash_profile
    source ~/.bash_profile
fi

# Configure qmake
if ! grep --quiet "export QMAKE" ~/.bash_profile; then
    echo "### Adding qmake to profile..."
    echo "export QMAKE=/usr/lib64/qt4/bin/qmake" >> ~/.bash_profile
    echo "export PATH=\$PATH:/usr/lib64/qt4/bin" >> ~/.bash_profile
    echo "export QTDIR=/usr/lib64/qt4/bin" >> ~/.bash_profile
    source ~/.bash_profile
fi

echo "### Installing ruby from rvm..."
# Ruby via rvm - from rvm.io
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -sSL https://raw.githubusercontent.com/rvm/rvm/master/binscripts/rvm-installer | bash -s stable
source /home/vagrant/.rvm/scripts/rvm
rvm install ruby-2.3 >> CentOS_ruby.txt 2>&1
rvm --default use 2.3

# Don't install documentation for gems
cat > ~/.gemrc <<EOT
  install: --no-document
  update: --no-document
EOT

# gem installs are *very* slow, hence all the checks in place here to facilitate debugging
echo "### Installing cucumber gems..."
gem list --local | grep -q mime-types
if [ $? -eq 1 ]; then
   gem install mime-types
fi
gem list --local | grep -q cucumber
if [ $? -eq 1 ]; then
   gem install cucumber
fi
gem list --local | grep -q capybara-webkit
if [ $? -eq 1 ]; then
   gem install capybara-webkit
fi
gem list --local | grep -q selenium-webdriver
if [ $? -eq 1 ]; then
   gem install selenium-webdriver
fi
gem list --local | grep -q rspec
if [ $? -eq 1 ]; then
   gem install rspec
fi
gem list --local | grep -q capybara-screenshot
if [ $? -eq 1 ]; then
   gem install capybara-screenshot
fi
gem list --local | grep -q selenium-cucumber
if [ $? -eq 1 ]; then
   gem install selenium-cucumber
fi

# Make sure that we are in ~ before trying to wget & install stuff
cd ~

# This is commented out since it tries to install qt3. Once we get the core building, this will get
# re-added
# if  ! rpm -qa | grep google-chrome-stable; then
#     echo "### Installing Chrome..."
#     if [ ! -f google-chrome-stable_current_x86_64.rpm ]; then
#       wget --quiet https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
#     fi
#     sudo yum -y install ./google-chrome-stable_current_*.rpm
# fi

if [ ! -f bin/chromedriver ]; then
    echo "### Installing Chromedriver..."
    mkdir -p $HOME/bin
    if [ ! -f chromedriver_linux64.zip ]; then
      wget --quiet http://chromedriver.storage.googleapis.com/2.14/chromedriver_linux64.zip
    fi
    unzip -d $HOME/bin chromedriver_linux64.zip
fi

cd ~

echo "### Installing Tomcat8..."
# NOTE: We could pull the RPM from the Hoot repo and install it instead of doing all of the manual steps.
#sudo bash -c "cat >> /etc/yum.repos.d/hoot.repo" <<EOT
# [hoot]
# name=hoot
# baseurl=https://s3.amazonaws.com/hoot-rpms/snapshot/el6/
# gpgcheck=0
#EOT

# Or
# wget https://s3.amazonaws.com/hoot-rpms/snapshot/el6/tomcat8-8.5.8-1.noarch.rpm
# rpm -ivh tomcat8-8.5.8-1.noarch.rpm


# Manual Install
sudo groupadd tomcat
sudo useradd -M -s /bin/nologin -g tomcat -d /var/lib/tomcat8 tomcat

if [ ! -f apache-tomcat-8.5.9.tar.gz ]; then
    wget http://apache.mirrors.ionfish.org/tomcat/tomcat-8/v8.5.9/bin/apache-tomcat-8.5.9.tar.gz
fi

sudo mkdir /var/lib/tomcat8
sudo tar xvf apache-tomcat-8*tar.gz -C /var/lib/tomcat8 --strip-components=1
cd /var/lib/tomcat8
sudo chgrp -R tomcat /var/lib/tomcat8
sudo chmod -R g+r conf
sudo chmod g+x conf
sudo chown -R tomcat webapps/ work/ temp/ logs/

sudo bash -c "cat >> /etc/systemd/system/tomcat.service" <<EOT
# Systemd unit file for tomcat
[Unit]
Description=Apache Tomcat Web Application Container
After=syslog.target network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/java/jdk1.8.0_111
Environment=CATALINA_PID=/var/lib/tomcat8/temp/tomcat.pid
Environment=CATALINA_HOME=/var/lib/tomcat8
Environment=CATALINA_BASE=/var/lib/tomcat8
Environment='CATALINA_OPTS=-Xms512M -Xmx2048M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

ExecStart=/var/lib/tomcat8/bin/startup.sh
ExecStop=/bin/kill -15 $MAINPID

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.targetEOT
EOT

# Start Tomcat8
sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat


# Configure Tomcat for the user
if ! grep --quiet TOMCAT8_HOME ~/.bash_profile; then
    echo "### Adding Tomcat to profile..."
    echo "export TOMCAT8_HOME=/var/lib/tomcat8" >> ~/.bash_profile
    source ~/.bash_profile
fi


exit

# This is commented out. Once we get Hoot compiling, then it can go back in

# TODO: Add check for previously installed GDAL
# download gdal for compiling, we do this so we get the desired version and can configure it
 if ! ogrinfo --formats | grep --quiet FileGDB; then
    if [ ! -f gdal-1.10.1.tar.gz ]; then
        echo "### Downloading GDAL source..."
        wget --quiet http://download.osgeo.org/gdal/1.10.1/gdal-1.10.1.tar.gz
    fi
    if [ ! -d gdal-1.10.1 ]; then
        echo "### Extracting GDAL source..."
        tar zxfp gdal-1.10.1.tar.gz
    fi
    if [ ! -f FileGDB_API_1_3-64.tar.gz ]; then
        echo "### Downloading FileGDB API source..."
        wget --quiet http://downloads2.esri.com/Software/FileGDB_API_1_3-64.tar.gz
    fi
    if [ ! -d /usr/local/FileGDB_API ]; then
        echo "### Extracting FileGDB API source & installing lib..."
        sudo tar xfp FileGDB_API_1_3-64.tar.gz --directory /usr/local
        sudo sh -c "echo '/usr/local/FileGDB_API/lib' > /etc/ld.so.conf.d/filegdb.conf"
    fi

    # compile gdal
    echo "### Building GDAL w/ FileGDB..."
    export PATH=/usr/local/lib:/usr/local/bin:$PATH
    cd gdal-1.10.1
    echo "GDAL: configure"
    sudo ./configure --quiet --with-fgdb=/usr/local/FileGDB_API --with-pg=/usr/bin/pg_config --with-python
    echo "GDAL: make"
    sudo make -sj$(nproc) > GDAL_Build.txt 2>&1
    echo "GDAL: install"
    sudo make -s install >> GDAL_Build.txt 2>&1
    cd swig/python
    echo "GDAL: python build"
    python setup.py build >> GDAL_Build.txt 2>&1
    echo "GDAL: python install"
    sudo python setup.py install >> GDAL_Build.txt 2>&1
    sudo ldconfig
    cd ~
    GDAL_DATA=/usr/local/share/gdal
    GDAL_LIB_DIR=/usr/local/lib

    # Remove gdal libs installed by libgdal-dev that interfere with
    # renderdb-export-server using gdal libs compiled from source (fgdb support)
    if [ -f "/usr/lib/libgdal.*" ]; then
        echo "Removing GDAL libs installed by libgdal-dev..."
        sudo rm /lib64/libgdal.*
    fi
fi # End GDAL




