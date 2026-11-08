#!/bin/bash
# Restaure une sauvegarde : ./restore.sh backups/AAAAMMJJ-HHMMSS
# Il faut que les conteneurs tournent (./install.sh)
cd "$(dirname "$0")"
source .env
SRC="${1%/}"

# 1) Vérifie la sauvegarde et demande confirmation
[ -f "$SRC/dolibarr.sql" ] || { echo "Usage : ./restore.sh backups/AAAAMMJJ-HHMMSS"; exit 1; }
read -p "1) Les données actuelles vont être remplacées par $SRC. Continuer ? (o/N) " R
[ "$R" = "o" ] || exit 0

# 2) Restaure la base (le dump remplace les tables existantes)
echo "2) Restauration de la base..."
docker exec -i -e MYSQL_PWD="$DB_ROOT_PASSWORD" dolibarr-db mariadb -uroot "$DB_NAME" < "$SRC/dolibarr.sql" \
    || { echo "Échec de la restauration de la base"; exit 1; }

# 3) Restaure les documents et conf.php
echo "3) Restauration des documents et de la configuration..."
docker exec -i dolibarr-app tar xzf - -C /var/www < "$SRC/documents.tar.gz"
[ -f "$SRC/conf.php" ] && docker cp "$SRC/conf.php" dolibarr-app:/var/www/html/conf/conf.php
docker exec dolibarr-app chown -R www-data:www-data /var/www/documents /var/www/html/conf

# 4) Redémarre Dolibarr et vérifie
echo "4) Redémarrage de Dolibarr..."
docker restart dolibarr-app >/dev/null
NB=$(docker exec -e MYSQL_PWD="$DB_ROOT_PASSWORD" dolibarr-db mariadb -uroot "$DB_NAME" -N -e "SELECT COUNT(*) FROM llx_societe")
echo "Restauration OK : $NB tiers"
