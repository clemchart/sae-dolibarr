#!/bin/bash
# Importe les tiers d'un fichier CSV (data/tiers.csv par défaut) dans Dolibarr
cd "$(dirname "$0")"   # va dans le dossier du script
source .env            # charge les variables (mots de passe, nom de la base)
FICHIER="${1:-tiers.csv}"   # 1er argument ; s'il est absent : tiers.csv
# Raccourci SQL dans le conteneur : -i = accepte du texte en entrée, -e MYSQL_PWD = mot de passe,
# --local-infile=1 = autorise la lecture du CSV, -uroot = utilisateur root
SQL="docker exec -i -e MYSQL_PWD=$DB_ROOT_PASSWORD dolibarr-db mariadb --local-infile=1 -uroot $DB_NAME"

# 1) Vérifie que le fichier et la base existent
[ -f "data/$FICHIER" ] || { echo "Fichier introuvable : data/$FICHIER"; exit 1; }
# Collation = règle de comparaison du texte (accents, majuscules) ; -N = sans nom de colonne
COLL=$($SQL -N -e "SELECT TABLE_COLLATION FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='llx_societe'")
[ -n "$COLL" ] || { echo "Dolibarr n'est pas installé : lance d'abord ./install.sh"; exit 1; }   # -n = non vide
echo "1) Fichier data/$FICHIER trouvé."
AVANT=$($SQL -N -e "SELECT COUNT(*) FROM llx_societe")   # nombre de tiers avant l'import

# 2) Charge le CSV dans une table temporaire, puis copie les nouveaux tiers dans llx_societe
echo "2) Import en cours..."
# <<FIN ... FIN = tout le texte entre les deux est envoyé comme SQL à mariadb
$SQL <<FIN || { echo "Échec de l'import"; exit 1; }
-- Table temporaire : disparait toute seule a la fin de la connexion
CREATE TEMPORARY TABLE tmp_tiers (
    nom VARCHAR(128), client INT, fournisseur INT,
    code_client VARCHAR(24), code_fournisseur VARCHAR(24),
    address VARCHAR(255), zip VARCHAR(25), town VARCHAR(50),
    country_code VARCHAR(3), phone VARCHAR(20), email VARCHAR(128), status INT
) DEFAULT CHARSET=utf8mb4 COLLATE=$COLL;

-- Lit le CSV : colonnes separees par un point-virgule, 1re ligne (en-tete) ignoree
LOAD DATA LOCAL INFILE '/data/$FICHIER' INTO TABLE tmp_tiers
    CHARACTER SET utf8mb4 FIELDS TERMINATED BY ';' IGNORE 1 LINES;

-- codes vides -> NULL, code pays -> id pays, tiers déjà présents ignorés
INSERT INTO llx_societe
    (nom, entity, client, fournisseur, code_client, code_fournisseur,
     address, zip, town, fk_pays, phone, email, status, datec)
SELECT t.nom, 1, t.client, t.fournisseur,
       -- NULLIF(a, '') donne NULL si a est vide (un index unique refuse deux codes vides)
       NULLIF(t.code_client, ''), NULLIF(t.code_fournisseur, ''),
       t.address, t.zip, t.town,
       -- remplace le code pays (FR) par son identifiant dans la table des pays
       (SELECT rowid FROM llx_c_country WHERE code = t.country_code),
       t.phone, t.email, t.status, NOW()
FROM tmp_tiers t
-- evite les doublons : ajoute seulement les noms absents de la base
WHERE t.nom NOT IN (SELECT nom FROM llx_societe WHERE nom IS NOT NULL);
FIN

# 3) Affiche le résultat
APRES=$($SQL -N -e "SELECT COUNT(*) FROM llx_societe")
echo "3) $((APRES - AVANT)) tiers ajoutés ($APRES au total)"   # $((...)) = calcul
