#!/bin/bash

###############################################################################
## ##
## Auteur : Quentin DUVAL ##
## ##
## Synopsis : Script d’installation et de configuration automatique d'un ##
## serveur LAMP (Apache, MariaDB, PHP, phpMyAdmin, OpenSSH) ##
## ##
## Scénario : ##
## 1. Mise à jour des paquets et du système si besoin ##
## 2. Installation de Apache, MariaDB, PHP, phpMyAdmin et OpenSSH ##
## ##
###############################################################################

apt-get update
apt-get dist-upgrade
apt-get install apache2 -y
apt-get install php -y
apt-get install mariadb-server -y
mysql -u root -e "
use mysql;
update user set plugin='' where User='root';
flush privileges;"
systemctl restart mariadb.service
apt-get install php-mysql -y
chown -R www-data:www-data /var/www
sed -i 's/.*AllowOverride None.*/AllowOverride All/' /etc/php/*/apache2/php.ini
systemctl reload apache2


# Sortir du script en cas d'erreur
set -e

# Variables
FICHIER_DE_LOG="/var/log/install-lamp.log"
MOT_DE_PASSE_ROOT="root"
MOT_DE_PASSE_PMA=""

# Fonction pour l'affichage écran et la journalisation dans un fichier de log
suiviInstallation()
{
	echo "# $1"
	echo "#####" `date +"%d-%m-%Y %T"` "$1" >> $FICHIER_DE_LOG
}

# Fonction qui gère l'affichage d'un message de réussite
toutEstOK()
{
	echo -e " '--> \e[32mOK\e[0m"
}

# Fonction qui gère l'affichage d'un message d'erreur et l'arrêt du script en cas de problème
erreurOnSort()
{
	echo -e "\e[41m" `tail -1 $FICHIER_DE_LOG` "\e[0m"
	echo -e " '--> \e[31mUne erreur s'est produite\e[0m, consultez le fichier \e[93m$FICHIER_DE_LOG\e[0m pour plus d'informations"
	exit 1
}

# Installation des prérequis pour l'installation de paquets issus de dépôts personnalisés
suiviInstallation "Installation des prérequis pour l'installation de paquets issus de dépôts personnalisés"
apt-get -y install apt-transport-https lsb-release ca-certificates &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort


#importation signatures paquets :
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

#suivi d'installation : 
echo "deb https;//packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

#mise a jour paquet et installation si besoin :
echo apt update &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort && apt upgrade &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Installation des services Apache, MariaDB, PHP et SSH
suiviInstallation "Installation des services Apache, MariaDB, PHP et SSH"
apt-get -y install apache2 mariadb-server php libapache2-mod-php php-mysql openssh-server &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

#on initialise le mdp root :
echo -y mysql_secure_installation &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

#on fait l'import 
echo mysql -u root -p <gsb_restore.sql &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

#On vas dans le répértoir par défaut 
cd /var/www/html &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

#et on supprime l'index
rm index.html &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

#ensuite on décompresse l'archive gsb :
unzip GSB_Appli.zip &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

#puis on supprime le .zip
rm GSB_Appli.zip &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Autorisation de root à se connecter en SSH (2 opérations)
suiviInstallation "Autorisation de root à se connecter en SSH (2 opérations)"
sed -i '/^#PermitRootLogin* /a PermitRootLogin yes' /etc/ssh/sshd_config &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
systemctl reload ssh &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Configuration de MariaDB pour l’accès distant (2 opérations)
suiviInstallation "Configuration de MariaDB pour l’accès distant (2 opérations)"
sed -i -e 's/^bind-address/#bind-address/' /etc/mysql/mariadb.conf.d/50-server.cnf &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
systemctl restart mariadb &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Création d'un compte admin pour l'administration de MariaDB
suiviInstallation "Création d'un compte admin pour l'administration de MariaDB"
mariadb -u root -e "CREATE USER admin@'%'; GRANT ALL PRIVILEGES ON *.* to admin@'%' IDENTIFIED BY '$MOT_DE_PASSE_ADMIN_MARIADB' WITH GRANT OPTION; FLUSH PRIVILEGES;" &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Installation de phpMyAdmin (2 opérations)
suiviInstallation "Configuration pré-installation de phpMyAdmin"
echo phpmyadmin phpmyadmin/dbconfig-install boolean true | debconf-set-selections &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
echo phpmyadmin phpmyadmin/app-password-confirm password $MOT_DE_PASSE_ROOT | debconf-setselections &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
			#echo phpmyadmin phpmyadmin/mysql/admin-pass password $MOT_DE_PASSE_PMA | debconf-setselections &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
echo phpmyadmin phpmyadmin/mysql/app-pass password $MOT_DE_PASSE_PMA | debconf-setselections &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
echo phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2 | debconf-setselections &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort
suiviInstallation "Installation de phpMyAdmin"
apt-get -y install phpmyadmin --no-install-recommends &>>$FICHIER_DE_LOG && toutEstOK ||erreurOnSort

# Fin
suiviInstallation "Le serveur est prêt !" && exit 0