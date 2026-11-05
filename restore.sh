#!/bin/bash
# Restauration d'une sauvegarde : ./restore.sh backups/AAAAMMJJ-HHMMSS
# Prérequis : conteneurs lancés par ./install.sh
cd "$(dirname "$0")"
source .env
SRC="${1%/}"

[ -f "$SRC/dolibarr.sql" ] || { echo "Usage : ./restore.sh backups/AAAAMMJJ-HHMMSS"; exit 1; }
read -p "Les données actuelles vont être écrasées par $SRC. Continuer ? (o/N) " R
[ "$R" = "o" ] || exit 0

# Le dump contient des DROP TABLE : il remplace les tables de l'installation neuve
docker exec -i -e MYSQL_PWD="$DB_ROOT_PASSWORD" dolibarr-db mariadb -uroot "$DB_NAME" < "$SRC/dolibarr.sql" \
    || { echo "Échec de la restauration de la base"; exit 1; }

docker exec -i dolibarr-app tar xzf - -C /var/www < "$SRC/documents.tar.gz"
[ -f "$SRC/conf.php" ] && docker cp "$SRC/conf.php" dolibarr-app:/var/www/html/conf/conf.php
docker exec dolibarr-app chown -R www-data:www-data /var/www/documents /var/www/html/conf

docker restart dolibarr-app >/dev/null
NB=$(docker exec -e MYSQL_PWD="$DB_ROOT_PASSWORD" dolibarr-db mariadb -uroot "$DB_NAME" -N -e "SELECT COUNT(*) FROM llx_societe")
echo "Restauration OK : $NB tiers"
