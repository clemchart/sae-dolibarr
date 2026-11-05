#!/bin/bash
# Sauvegarde complète : base, documents et conf.php dans backups/AAAAMMJJ-HHMMSS/
cd "$(dirname "$0")"
source .env
DEST="backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DEST"

# --single-transaction : dump cohérent sans bloquer Dolibarr (InnoDB)
docker exec -e MYSQL_PWD="$DB_ROOT_PASSWORD" dolibarr-db \
    mariadb-dump -uroot --single-transaction --routines "$DB_NAME" > "$DEST/dolibarr.sql" \
    || { echo "Échec du dump de la base"; rm -rf "$DEST"; exit 1; }

# documents/ contient les fichiers joints et install.lock
docker exec dolibarr-app tar czf - -C /var/www documents > "$DEST/documents.tar.gz" \
    || { echo "Échec de la sauvegarde des documents"; exit 1; }

# conf.php contient l'identifiant unique de l'instance (utilisé pour le chiffrement)
docker cp dolibarr-app:/var/www/html/conf/conf.php "$DEST/conf.php"

echo "Sauvegarde OK : $DEST ($(du -sh "$DEST" | cut -f1))"
