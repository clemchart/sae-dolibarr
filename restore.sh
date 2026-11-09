#!/bin/bash
# Restaure une sauvegarde : ./restore.sh backups/AAAAMMJJ-HHMMSS
# Il faut que les conteneurs tournent (./install.sh)
cd "$(dirname "$0")"   # va dans le dossier du script
source .env            # charge les variables (mot de passe, nom de la base)
SRC="${1%/}"           # dossier de sauvegarde donné en argument, sans "/" final

# 1) Vérifie la sauvegarde et demande confirmation
[ -f "$SRC/dolibarr.sql" ] || { echo "Usage : ./restore.sh backups/AAAAMMJJ-HHMMSS"; exit 1; }   # -f = fichier existe ?
read -p "1) Les données actuelles vont être remplacées par $SRC. Continuer ? (o/N) " R   # read -p = pose la question
[ "$R" = "o" ] || exit 0   # toute réponse autre que "o" annule

# 2) Restaure la base (le dump remplace les tables existantes)
echo "2) Restauration de la base..."
# docker exec -i = accepte du texte en entrée ; -e = donne le mot de passe au conteneur
# le < envoie le fichier .sql au client mariadb, qui exécute son contenu
docker exec -i -e MYSQL_PWD="$DB_ROOT_PASSWORD" dolibarr-db mariadb -uroot "$DB_NAME" < "$SRC/dolibarr.sql" \
    || { echo "Échec de la restauration de la base"; exit 1; }

# 3) Restaure les documents et conf.php
echo "3) Restauration des documents et de la configuration..."
# tar xzf - = extrait (x) l'archive compressée (z) reçue sur l'entrée (f -) ; -C = dossier de destination
docker exec -i dolibarr-app tar xzf - -C /var/www < "$SRC/documents.tar.gz"
# && = copie conf.php seulement s'il existe dans la sauvegarde
[ -f "$SRC/conf.php" ] && docker cp "$SRC/conf.php" dolibarr-app:/var/www/html/conf/conf.php
# chown -R = change le propriétaire de tous les fichiers (récursif) pour www-data, l'utilisateur d'Apache
docker exec dolibarr-app chown -R www-data:www-data /var/www/documents /var/www/html/conf

# 4) Redémarre Dolibarr et vérifie
echo "4) Redémarrage de Dolibarr..."
docker restart dolibarr-app >/dev/null   # >/dev/null = cache la sortie
# mariadb : -N = sans nom de colonne ; -e = requête à exécuter
NB=$(docker exec -e MYSQL_PWD="$DB_ROOT_PASSWORD" dolibarr-db mariadb -uroot "$DB_NAME" -N -e "SELECT COUNT(*) FROM llx_societe")
echo "Restauration OK : $NB tiers"
