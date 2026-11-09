#!/bin/bash
# Sauvegarde la base, les documents et conf.php dans backups/AAAAMMJJ-HHMMSS/
cd "$(dirname "$0")"   # va dans le dossier du script
source .env            # charge les variables (mot de passe, nom de la base)
DEST="backups/$(date +%Y%m%d-%H%M%S)"   # dossier daté, ex. backups/20261109-143000
mkdir -p "$DEST"                        # -p = crée aussi backups/ et pas d'erreur s'il existe

# 1) Sauvegarde la base (sans bloquer Dolibarr)
echo "1) Sauvegarde de la base..."
# mariadb-dump = exporte la base en SQL ; --single-transaction = copie cohérente sans verrouiller ;
# --routines = inclut les procédures stockées ; > = écrit dans un fichier sur ta machine
# || { ... } = si ça échoue : supprime le dossier (rm -rf) et arrête (exit 1)
docker exec -e MYSQL_PWD="$DB_ROOT_PASSWORD" dolibarr-db \
    mariadb-dump -uroot --single-transaction --routines "$DB_NAME" > "$DEST/dolibarr.sql" \
    || { echo "Échec de la sauvegarde de la base"; rm -rf "$DEST"; exit 1; }

# 2) Sauvegarde les documents (fichiers joints, install.lock)
echo "2) Sauvegarde des documents..."
# tar czf - = crée (c) une archive compressée (z) et l'envoie à l'écran (f -)
# -C /var/www = se place dans ce dossier avant d'archiver "documents"
# le > récupère l'archive sur ta machine, rien n'est écrit dans le conteneur
docker exec dolibarr-app tar czf - -C /var/www documents > "$DEST/documents.tar.gz" \
    || { echo "Échec de la sauvegarde des documents"; exit 1; }

# 3) Sauvegarde conf.php (contient la clé unique de l'instance)
echo "3) Sauvegarde de la configuration..."
docker cp dolibarr-app:/var/www/html/conf/conf.php "$DEST/conf.php"   # copie conteneur -> machine

# du -sh = taille du dossier (-s total, -h lisible) ; cut -f1 = garde la 1re colonne
echo "Sauvegarde OK : $DEST ($(du -sh "$DEST" | cut -f1))"
