#!/bin/bash
# Import des tiers (CSV ;) dans le Dolibarr dockerisé.
# data/ est monté en lecture seule dans le conteneur db sous /data (voir docker-compose.yml).
cd "$(dirname "$0")"
source .env
FICHIER="${1:-tiers.csv}"
SQL="docker exec -i -e MYSQL_PWD=$DB_ROOT_PASSWORD dolibarr-db mariadb --local-infile=1 -uroot $DB_NAME"

[ -f "data/$FICHIER" ] || { echo "Fichier introuvable : data/$FICHIER"; exit 1; }

# La table temporaire doit avoir la même collation que llx_societe (sinon erreur 1267)
COLL=$($SQL -N -e "SELECT TABLE_COLLATION FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='llx_societe'")
[ -n "$COLL" ] || { echo "Table llx_societe absente : lancer d'abord ./install.sh"; exit 1; }

AVANT=$($SQL -N -e "SELECT COUNT(*) FROM llx_societe")

$SQL <<FIN || { echo "Échec de l'import"; exit 1; }
CREATE TEMPORARY TABLE tmp_tiers (
    nom VARCHAR(128), client INT, fournisseur INT,
    code_client VARCHAR(24), code_fournisseur VARCHAR(24),
    address VARCHAR(255), zip VARCHAR(25), town VARCHAR(50),
    country_code VARCHAR(3), phone VARCHAR(20), email VARCHAR(128), status INT
) DEFAULT CHARSET=utf8mb4 COLLATE=$COLL;

LOAD DATA LOCAL INFILE '/data/$FICHIER' INTO TABLE tmp_tiers
    CHARACTER SET utf8mb4 FIELDS TERMINATED BY ';' IGNORE 1 LINES;

-- Codes vides -> NULL (index uniques), pays converti en fk_pays, doublons ignorés sur le nom
INSERT INTO llx_societe
    (nom, entity, client, fournisseur, code_client, code_fournisseur,
     address, zip, town, fk_pays, phone, email, status, datec)
SELECT t.nom, 1, t.client, t.fournisseur,
       NULLIF(t.code_client, ''), NULLIF(t.code_fournisseur, ''),
       t.address, t.zip, t.town,
       (SELECT rowid FROM llx_c_country WHERE code = t.country_code),
       t.phone, t.email, t.status, NOW()
FROM tmp_tiers t
WHERE t.nom NOT IN (SELECT nom FROM llx_societe WHERE nom IS NOT NULL);
FIN

APRES=$($SQL -N -e "SELECT COUNT(*) FROM llx_societe")
echo "$((APRES - AVANT)) tiers ajoutés ($APRES au total)"
