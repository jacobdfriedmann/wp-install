#!/bin/bash

#This script connects to a Wordpress project by downloading it from a Github repo.
#You can either pass in a configuration file or answer a series of conf questions.

#Get some info

if [ $# -eq 0 ]; then
	read -p "What is your local MySql Username?" mysqluname
	read -p "What is your local MySql Password?" mysqlpwd
	read -p "What port does MySql listen on locally?" mysqlport
	read -p "What is your AWS access key id?" awskey
	read -p "What is your AWS secret access key?" awssecret 
	read -p "Where is the GitHub repository located" githubloc
	read -p "What is the name of the Heroku app?" herokuapp
else
	conf=$1
	mysqluname=`cat $conf | grep LOCAL_MYSQL_USER | cut -d = -f 2`
	mysqlpwd=`cat $conf | grep LOCAL_MYSQL_PASSWORD | cut -d = -f 2`
	mysqlport=`cat $conf | grep LOCAL_MYSQL_PORT | cut -d = -f 2`
	awskey=`cat $conf | grep AWS_ACCESS_KEY_ID | cut -d = -f 2`
	awssecret=`cat $conf | grep AWS_SECRET_ACCESS_KEY | cut -d = -f 2`
	githubloc=`cat $conf | grep GITHUB_LOCATION | cut -d = -f 2`
	herokuapp=`cat $conf | grep HEROKU_APP | cut -d = -f 2`
	mysql=`cat $conf | grep MYSQL_LOCATION | cut -d = -f 2`
	mysqldump=`cat $conf | grep MYSQLDUMP_LOCATION | cut -d = -f 2`
	php=`cat $conf | grep PHP_LOCATION | cut -d = -f 2`
fi

if [ ${#mysql} -eq 0 ]; then
	mysql=mysql
fi
if [ ${#mysqldump} -eq 0 ]; then
	mysql=mysqldump
fi
if [ ${#php} -eq 0 ]; then
	php=php
fi

#Clone the GitHub repo
git clone $githubloc

#Add Heroku remote
project=${githubloc##*/}
cd $project
git remote add heroku git@heroku.com:$herokuapp.git

#Create local db
$mysql --host=localhost -u $mysqluname -p$mysqlpwd -e "CREATE DATABASE \`$project\`;"
databaseurl="mysql://$mysqluname:$mysqlpwd@127.0.0.1:$mysqlport/$project"

#Make Procfile and .gitignore
touch Procfile
touch .gitignore
echo "web: $php -S localhost:5000 -t ." > Procfile
echo "Procfile" > .gitignore
echo ".env" >> .gitignore
echo ".htaccess" >> .gitignore

#Get Random Salts for config
curl https://api.wordpress.org/secret-key/1.1/salt/ > salt.txt
authkey=`head -n 1 salt.txt | cut -c 29-92`
secureauthkey=`head -n 2 salt.txt | cut -c 29-92`
loggedinkey=`head -n 3 salt.txt | cut -c 29-92`
noncekey=`head -n 4 salt.txt | cut -c 29-92`
authsalt=`head -n 5 salt.txt | cut -c 29-92`
secureauthsalt=`head -n 6 salt.txt | cut -c 29-92`
loggedinsalt=`head -n 7 salt.txt | cut -c 29-92`
noncesalt=`head -n 8 salt.txt | cut -c 29-92`
rm salt.txt

#Create local enviornmet variables
touch .env
echo "AUTH_KEY=\"$authkey\"" > .env
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


#Get a copy of the production db, import it locally
remote_url=`heroku config:get DATABASE_URL`
remote_user=`echo $remote_url | cut -c 9- | cut -d : -f 1`
remote_pass=`echo $remote_url | cut -d : -f 3 | cut -d @ -f 1` 
remote_host=`echo $remote_url | cut -d @ -f 2 | cut -d / -f 1`
remote_db=`echo $remote_url | cut -d : -f 3 | cut -d / -f 2 | cut -d ? -f 1`
$mysqldump --host=$remote_host -u $remote_user -p$remote_pass $remote_db > prod.sql
$mysql --host=localhost -u $mysqluname -p$mysqlpwd $project < prod.sql
rm prod.sql

#Update DB options for local dev
$mysql --host=localhost -u $mysqluname -p$mysqlpwd $project -e "UPDATE  \`wp_options\` SET  \`option_value\` =  'http://localhost:5000' WHERE  \`wp_options\`.\`option_name\` = 'siteurl';"
$mysql --host=localhost -u $mysqluname -p$mysqlpwd $project -e "UPDATE  \`wp_options\` SET  \`option_value\` =  'http://localhost:5000' WHERE  \`wp_options\`.\`option_name\` = 'home';"
