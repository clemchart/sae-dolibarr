#!/bin/bash
# Sauvegarde la base, les documents et conf.php dans backups/AAAAMMJJ-HHMMSS/
cd "$(dirname "$0")"
source .env
DEST="backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DEST"

# 1) Sauvegarde la base (sans bloquer Dolibarr)
echo "1) Sauvegarde de la base..."
docker exec -e MYSQL_PWD="$DB_ROOT_PASSWORD" dolibarr-db \
    mariadb-dump -uroot --single-transaction --routines "$DB_NAME" > "$DEST/dolibarr.sql" \
    || { echo "Échec de la sauvegarde de la base"; rm -rf "$DEST"; exit 1; }

# 2) Sauvegarde les documents (fichiers joints, install.lock)
echo "2) Sauvegarde des documents..."
docker exec dolibarr-app tar czf - -C /var/www documents > "$DEST/documents.tar.gz" \
    || { echo "Échec de la sauvegarde des documents"; exit 1; }

# 3) Sauvegarde conf.php (contient la clé unique de l'instance)
echo "3) Sauvegarde de la configuration..."
docker cp dolibarr-app:/var/www/html/conf/conf.php "$DEST/conf.php"

echo "Sauvegarde OK : $DEST ($(du -sh "$DEST" | cut -f1))"
