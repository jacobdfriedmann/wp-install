#!/bin/bash

#This script creates a new wordpress project, local development enviornment, github repository and heroku deployment.
#You can either pass in a configuration file or answer a series of configuration questions.

#Get some info for project
read -p "What shall we call this project?" project

if [ $# -eq 0 ]; then
	read -p "What is your local MySql Username?" mysqluname
	read -p "What is your local MySql Password?" mysqlpwd
	read -p "What port does MySql listen on locally?" mysqlport
	read -p "What is your AWS access key id?" awskey
	read -p "What is your AWS secret access key?" awssecret 
	read -p "What is your GitHub username?" ghubname
else
	conf=$1
	mysqluname=`cat $conf | grep LOCAL_MYSQL_USER | cut -d = -f 2`
	if [ ${#mysqluname} -eq 0 ]; then
		read -p "What is your local MySql Username?" mysqluname
	fi
	mysqlpwd=`cat $conf | grep LOCAL_MYSQL_PASSWORD | cut -d = -f 2`
	if [ ${#mysqlpwd} -eq 0 ]; then
		read -p "What is your local MySql Password?" mysqlpwd
	fi
	mysqlport=`cat $conf | grep LOCAL_MYSQL_PORT | cut -d = -f 2`
	if [ ${#mysqlpwd} -eq 0 ]; then
		read -p "What port does MySql listen on locally?" mysqlport
	fi
	awskey=`cat $conf | grep AWS_ACCESS_KEY_ID | cut -d = -f 2`
	if [ ${#awskey} -eq 0 ]; then
		read -p "What is your AWS access key id?" awskey
	fi
	awssecret=`cat $conf | grep AWS_SECRET_ACCESS_KEY | cut -d = -f 2`
	if [ ${#awssecret} -eq 0 ]; then
		read -p "What is your AWS secret access key?" awssecret
	fi
	ghubname=`cat $conf | grep GITHUB_USERNAME | cut -d = -f 2`
	if [ ${#ghubname} -eq 0 ]; then
		read -p "What is your GitHub username?" ghubname
	fi
	mysql=`cat $conf | grep MYSQL_LOCATION | cut -d = -f 2`
	httpd=`cat $conf | grep HTTPD_LOCATION | cut -d = -f 2`
fi

if [ ${#mysql} -eq 0 ]; then
	mysql=mysql
fi
if [ ${#httpd} -eq 0 ]; then
	httpd=httpd
fi

#Make Project Directory
mkdir $project

#Download WordPress
curl -O http://wordpress.org/latest.zip
unzip latest.zip -d $project
mv $project/wordpress/* $project
rm -rf $project/wordpress
rm latest.zip

#Download wp-config file
cd $project
curl -o wp-config.php https://gist.githubusercontent.com/jacobdfriedmann/67b1fba902f455ce607c/raw/0055562bac32599c42bc91d78ce99d84d12d0162/gistfile1.txt
rm wp-config-sample.php

#Make Procfile and .gitignore
touch Procfile
touch .gitignore
echo "web: ./boot.sh" > Procfile
echo "Procfile" > .gitignore
echo ".env" >> .gitignore
echo "boot.sh" >> .gitignore
echo "httpd*" >> .gitignore
echo "logs" >> .gitignore

#Download necessary plugins
cd wp-content/plugins
curl -O http://downloads.wordpress.org/plugin/amazon-web-services.0.1.zip
unzip amazon-web-services.0.1.zip
rm amazon-web-services.0.1.zip
curl -O http://downloads.wordpress.org/plugin/amazon-s3-and-cloudfront.0.6.1.zip
unzip amazon-s3-and-cloudfront.0.6.1.zip
rm amazon-s3-and-cloudfront.0.6.1.zip

#Set up local db
cd ../../
$mysql --host=localhost -u $mysqluname -p$mysqlpwd -e "CREATE DATABASE \`$project\`;"
databaseurl="mysql://$mysqluname:$mysqlpwd@127.0.0.1:$mysqlport/$project"

#Get Random Salts for config
curl https://api.wordpress.org/secret-key/1.1/salt/ > salt.txt
authkey=`head -n 1 salt.txt | tail -n 1 | cut -c 29-92`
secureauthkey=`head -n 2 salt.txt | tail -n 1 | cut -c 29-92`
loggedinkey=`head -n 3 salt.txt | tail -n 1 | cut -c 29-92`
noncekey=`head -n 4 salt.txt | tail -n 1 | cut -c 29-92`
authsalt=`head -n 5 salt.txt | tail -n 1 | cut -c 29-92`
secureauthsalt=`head -n 6 salt.txt | tail -n 1 | cut -c 29-92`
loggedinsalt=`head -n 7 salt.txt | tail -n 1 | cut -c 29-92`
noncesalt=`head -n 8 salt.txt | tail -n 1 | cut -c 29-92`
rm salt.txt

#Create local enviornmet variables
touch .env
echo "AUTH_KEY=\"$authkey\"" >> .env
echo "SECURE_AUTH_KEY=\"$secureauthkey\"" >> .env
echo "LOGGED_IN_KEY=\"$loggedinkey\"" >> .env
echo "NONCE_KEY=\"$noncekey\"" >> .env
echo "AUTH_SALT=\"$authsalt\"" >> .env
echo "SECURE_AUTH_SALT=\"$secureauthsalt\"" >> .env
echo "LOGGED_IN_SALT=\"$loggedinsalt\"" >> .env
echo "NONCE_SALT=\"$noncesalt\"" >> .env
echo "DATABASE_URL=\"$databaseurl\"" >> .env
echo "AWS_ACCESS_KEY_ID=\"$awskey\"" >> .env
echo "AWS_SECRET_ACCESS_KEY=\"$awssecret\"" >> .env

#Make boot script
cat >>boot.sh <<EOF
sed -i.bak '/PassEnv*/d' httpd.conf
for var in \`env|cut -f1 -d=\`; do
  echo "PassEnv \$var" >> httpd.conf;
done
touch logs/apache_error_log
touch logs/access_log
tail -F logs/apache_error_log &
tail -F logs/access_log &
echo "Launching apache"
exec $httpd -DNO_DETACH -f \`pwd\`/httpd.conf
EOF

chmod +x boot.sh

#Set up apache
aconfig=`$httpd -V | grep SERVER_CONFIG_FILE | cut -d = -f 2`
aconfig="${aconfig%\"}"
aconfig="${aconfig#\"}"
cat $aconfig | grep LoadModule > httpd.conf
phpmodule=`cat httpd.conf | grep \# | grep php`
if [ ${#phpmodule} -gt 0 ]; then
	new_module=`echo $phpmodule | cut -c 2-`
	sed -i.bak "s~${phpmodule}~${new_module}~g" httpd.conf
fi
cat >>httpd.conf <<EOF
DocumentRoot "`pwd`"

<Directory "`pwd`">
	Options Indexes FollowSymLinks MultiViews
	AllowOverride None
	Order allow,deny
    Allow from all
</Directory>

PidFile "`pwd`/logs/httpd.pid"
LockFile "`pwd`/logs/accept.lock"

Listen 5000

ErrorLog "`pwd`/logs/apache_error_log"

<IfModule log_config_module>
    LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%h %l %u %t \"%r\" %>s %b" common
    <IfModule logio_module>
      # You need to enable mod_logio.c to use %I and %O
      LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %I %O" combinedio
    </IfModule>
    CustomLog "`pwd`/logs/access_log" common
</IfModule>

<IfModule php5_module>
	AddType application/x-httpd-php .php
	AddType application/x-httpd-php-source .phps

	<IfModule dir_module>
		DirectoryIndex index.html index.php
	</IfModule>
</IfModule>
EOF
mkdir logs

#Set up git and github repo
curl -u $ghubname https://api.github.com/user/repos -d "{\"name\": \"$project\"}"
origin="https://github.com/$ghubname/$project.git"
git init
git remote add origin $origin
git push origin

#Create heroku project
heroku apps:create
appname=`heroku apps:info | grep "===" | cut -c 5-`
heroku addons:add cleardb:ignite
heroku config:set DATABASE_URL=`heroku config:get CLEARDB_DATABASE_URL | cut -d ? -f 1`
heroku config:set AUTH_KEY="$authkey"
heroku config:set SECURE_AUTH_KEY="$secureauthkey"
heroku config:set LOGGED_IN_KEY="$loggedinkey"
heroku config:set NONCE_KEY="$noncekey"
heroku config:set AUTH_SALT="$authsalt"
heroku config:set SECURE_AUTH_SALT="$secureauthsalt"
heroku config:set LOGGED_IN_SALT="$loggedinsalt"
heroku config:set NONCE_SALT="$noncesalt"
heroku config:set AWS_ACCESS_KEY_ID="$awskey"
heroku config:set AWS_SECRET_ACCESS_KEY="$awssecret"

#Push to GitHub and Heroku
git add .
git commit -m "Initial Commit."
git push origin master
git push heroku master
