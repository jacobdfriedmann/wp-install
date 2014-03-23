#!/bin/bash

#This script rolls back a wp-install. Mainly used for testing, could also be used in case of incorrectly passed configuration.

#get some info
read -p "What project are we deleting?" project
read -p "(Local) Path to project?" path

if [ $# -eq 0 ]; then
	read -p "What is your github username?" githubname
	read -p "What is your local MySql Username?" mysqluname
	read -p "What is your local MySql Password?" mysqlpwd
	read -p "What port does MySql listen on locally?" mysqlport
else
	conf=$1
	githubname=`cat $conf | grep GITHUB_USERNAME | cut -d = -f 2`
	mysqluname=`cat $conf | grep LOCAL_MYSQL_USER | cut -d = -f 2`
	mysqlpwd=`cat $conf | grep LOCAL_MYSQL_PASSWORD | cut -d = -f 2`
	mysqlport=`cat $conf | grep LOCAL_MYSQL_PORT | cut -d = -f 2`
	mysql=`cat $conf | grep MYSQL_LOCATION | cut -d = -f 2`
	if [ ${#mysql} -eq 0 ]; then
		mysql=mysql
	fi
fi

#Delete local MySQL DB
$mysql --host=localhost -u $mysqluname -p$mysqlpwd -e "DROP DATABASE \`$project\`;"

#Delete GitHub Repo
curl -u $githubname -X "DELETE" https://api.github.com/repos/$githubname/$project

#Delete Heroku App
cd $path
appname=`heroku apps:info | grep "===" | cut -c 5-`
heroku apps:destroy --app $appname

#Delete local files
cd ../
rm -rf $path
