from ubuntu:14.04
maintainer akhilraj

run apt-get update && sudo apt-get -y upgrade
run apt-get install -y apache2 php5 libapache2-mod-php5 mysql-server php5-mysql \
		       libapache2-mod-perl2 libcurl4-openssl-dev libssl-dev apache2-prefork-dev \
		       libapr1-dev libaprutil1-dev libmysqlclient-dev libmagickcore-dev libmagickwand-dev \
		       curl git-core gitolite patch build-essential bison zlib1g-dev libssl-dev libxml2-dev \
		       libxml2-dev sqlite3 libsqlite3-dev autotools-dev libxslt1-dev libyaml-0-2 autoconf automake \ 
		       libreadline6-dev libyaml-dev libtool imagemagick apache2-utils ssh zip libicu-dev libssh2-1 \
		       libssh2-1-dev cmake libgpg-error-dev subversion libapache2-svn git nano tar unzip


#Configure Subversion

run mkdir -p /var/lib/svn
run chown -R www-data:www-data /var/lib/svn
run mkdir /opt/redmine

workdir /tmp
run git clone -b redmine https://github.com/akhilrajmailbox/redmine-3.0.4.git
run cp -r /tmp/redmine-3.0.4/* /opt/redmine/ && rm -rf /tmp/redmine-3.0.4

workdir /opt/redmine/
run rm -f /etc/apache2/mods-enabled/dav_svn.conf
run cp dav_svn.conf /etc/apache2/mods-enabled/
run cp dav_svn.passwd /etc/apache2/

run svnadmin create --fs-type fsfs /var/lib/svn/my_repository
run cp dav_svn.authz /etc/apache2/


#Installing Ruby and Ruby on Rails

run apt-get -y install  software-properties-common
run add-apt-repository ppa:brightbox/ruby-ng
run apt-get update
run apt-get -y install ruby2.1 ruby-switch ruby2.1-dev ri2.1 libruby2.1 libssl-dev zlib1g-dev
run ruby-switch --set ruby2.1


#Installing of Redmine

run gpg --keyserver hkp://pgp.mit.edu --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
run curl -sSL https://get.rvm.io | bash -s stable
run /bin/bash -l -c "rvm install 2.1.4"

#Redmine

workdir /opt/redmine
run wget http://www.redmine.org/releases/redmine-3.0.4.tar.gz
run tar xvfz redmine-3.0.4.tar.gz
run rm redmine-3.0.4.tar.gz
run mv redmine-3.0.4 redmine
workdir /opt/redmine/plugins
run find /opt/redmine/plugins/*.zip -exec unzip {} \; || pwd && rm -r /opt/redmine/plugins/*.zip || pwd
run tar xfj /opt/redmine/plugins/*.bz2 || pwd && rm -r /opt/redmine/plugins/*.bz2 || pwd
run cp -r /opt/redmine/plugins/* /opt/redmine/redmine/plugins/
run chown -R www-data:www-data /opt/redmine/*
run ln -s /opt/redmine/redmine/public /var/www/html/redmine

#Configure Redmine database connection

run gem update
run gem install bundler

workdir /opt/redmine
run cp database.yml /opt/redmine/redmine/config/

workdir /opt/redmine/redmine
run gem install mime-types-data -v '3.2016.0521'
run bundle install --without development test postgresql sqlite

run rake generate_secret_token
run rake redmine:plugins:migrate RAILS_ENV=production || pwd
run rake db:migrate RAILS_ENV=production
run RAILS_ENV=production REDMINE_LANG=fr bundle exec rake redmine:load_default_data
run rake redmine:plugins:migrate RAILS_ENV=production || pwd
run chown -R www-data:www-data files log tmp public/plugin_assets
run chmod -R 755 files log tmp public/plugin_assets


#Installing Phusion Passenger

run apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 561F9B9CAC40B2F7
run apt-get -y install apt-transport-https ca-certificates
workdir /opt/redmine
run cp passenger.list /etc/apt/sources.list.d/
run chown www-data:www-data /etc/apt/sources.list.d/passenger.list
run chmod 744 /etc/apt/sources.list.d/passenger.list

run apt-get update
run apt-get -y install libapache2-mod-passenger
run rm -f /etc/apache2/mods-available/passenger.conf


#apache2 configuration

workdir /opt/redmine
run mkdir /etc/apache2/ssl
run cp apache.key /etc/apache2/ssl
run cp apache.crt /etc/apache2/ssl

run rm -rf /etc/apache2/sites-available/default-ssl.conf
run rm -rf /etc/apache2/sites-available/000-default.conf

run cp 000-default.conf /etc/apache2/sites-available/
run cp default-ssl.conf /etc/apache2/sites-available/
run cp passenger.conf /etc/apache2/mods-available/
run a2ensite default-ssl.conf
run a2ensite 000-default.conf
run a2enmod passenger
run a2enmod ssl
run  chown -R www-data:www-data /opt/redmine/*

expose 80 443
entrypoint service apache2 start && tail -f /var/log/apache2/error.log && bash
