Utility Scripts for quickly developing WordPress Sites
======================================================

Tools for rapid development of WordPres sites, hosted on GitHub and deployed on Heroku.

Prerequisites
-------------

While these scripts are intended to make deploying or connecting to a new WordPress project super fast and easy, they make some assumptions about your local environment.

### Dependencies

- <b>Heroku toolbelt</b>: https://toolbelt.heroku.com/
- <b>MySQL</b>: http://dev.mysql.com/downloads/mysql/ (or MAMP or XAMP)
- <b>PHP</b>: Installed on most OS's (or use MAMP or XAMP)
- <b>curl</b>: Installed on many OS's (http://curl.haxx.se/download.html)
- <b>git</b>: Installed on some OS's (http://git-scm.com/downloads)

### Modify scripts

Shell scripts will have to be chmod-ed in order to be run:

	~$ chmod +x wp-install.sh
	~$ chmod +x wp-connect.sh
	~$ chmod +x wp-install-rollback.sh 

### Note on using MAMP or XAMP

If you are using MAMP or XAMP for MySQL or PHP or both, you must specify the location of the command in the wp-install.conf file. For example, the default location of the mysql command in MAMP is /Applications/MAMP/Library/bin/mysql. Here is an example conf excerpt for MAMP:

	MYSQL_LOCATION=/Applications/MAMP/Library/bin/mysql
	MYSQLDUMP_LOCATION=/Applications/MAMP/Library/bin/mysqldump
	PHP_LOCATION=/Applications/MAMP/bin/php/php5.5.3/bin/php

### Amazon Web Services for Uploads

Normally, WordPress uploads, such as images or videos, would be located on the servers local filesystem in the wp-content/uploads folder. Heroku, however, does not work well with this model because any changes made on the production site will be lost when a new version is pushed. The application must be entirely "stateless". To overcome this obstacle, we use an S3 bucket to store all uploads to the site. For this reason, you will need AWS keys. The scripts take care of getting a set of plugins to make this model work under the hood.


wp-install.sh
-------------
Create a new WordPress installation from scratch. Downloads the most recent version of WordPress, creates a local development environment, creates a GitHub repository for your project and finally deploys it to Heroku to run in test.

You can either answer a series of questions about configuration or pass in a separate conf file (see the wp-install.conf.example).

- Question mode:
		~$ ./wp-install.sh
- Configuration file mode:
		~$ ./wp-install.sh wp-install.conf

The project will be created in the current working directory.

wp-install-rollback.sh
----------------------
Undoes a wp-install. Mainly used for testing the wp-install script, but cn be used to undo a badly configured install. Removes local files, local database, GitHub repository and Heroku application. WARNING, CANNOT BE UNDONE.

- Question mode:
		~$ ./wp-install-rollback.sh
- Configuration file mode:
		~$ ./wp-install-rollback.sh wp-install.conf

wp-connect.sh
-------------
Downloads an existing WordPress project from GitHub and connects to the corresponding Heroku application. Dumps a copy of the Heroku app database and imports it locally. Creates a local development environment.

- Question mode:
		~$ ./wp-connect.sh
- Configuration file mode:
		~$ ./wp-connect.sh wp-install.conf