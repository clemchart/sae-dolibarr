#!/bin/bash
# Import des tiers (CSV ;) dans llx_societe. À lancer depuis la racine du dépôt.
# Version sans Docker, utilisée sur la VM (MariaDB installé directement)
FICHIER="${1:-data/tiers.csv}"   # 1er argument ; par défaut data/tiers.csv
BASE="dolibarr"
SQL="sudo mariadb"               # client MariaDB lancé en root, sans mot de passe

[ -f "$FICHIER" ] || { echo "Fichier introuvable : $FICHIER"; exit 1; }   # -f = fichier existe ?

# -N = sans nom de colonne ; -e = requête à exécuter
AVANT=$($SQL $BASE -N -e "SELECT COUNT(*) FROM llx_societe;")

# Collation imposée : celle des tables Dolibarr (sinon erreur 1267 sur la comparaison des noms)
# --local-infile=1 = autorise la lecture du CSV ; <<FIN ... FIN = le texte entre les deux est du SQL
$SQL --local-infile=1 $BASE <<FIN || { echo "Échec de l'import"; exit 1; }
-- Table temporaire : disparait toute seule a la fin de la connexion
CREATE TEMPORARY TABLE tmp_tiers (
    nom VARCHAR(128), client INT, fournisseur INT,
    code_client VARCHAR(24), code_fournisseur VARCHAR(24),
    address VARCHAR(255), zip VARCHAR(25), town VARCHAR(50),
    country_code VARCHAR(3), phone VARCHAR(20), email VARCHAR(128), status INT
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Lit le CSV : colonnes separees par un point-virgule, 1re ligne (en-tete) ignoree
LOAD DATA LOCAL INFILE '$FICHIER' INTO TABLE tmp_tiers
    CHARACTER SET utf8mb4 FIELDS TERMINATED BY ';' IGNORE 1 LINES;

-- Codes vides -> NULL (index uniques), pays converti en fk_pays, doublons ignorés sur le nom
INSERT INTO llx_societe
    (nom, entity, client, fournisseur, code_client, code_fournisseur,
     address, zip, town, fk_pays, phone, email, status, datec)
SELECT t.nom, 1, t.client, t.fournisseur,
       -- NULLIF(a, '') donne NULL si a est vide
       NULLIF(t.code_client, ''), NULLIF(t.code_fournisseur, ''),
       t.address, t.zip, t.town,
       -- remplace le code pays (FR) par son identifiant dans la table des pays
       (SELECT rowid FROM llx_c_country WHERE code = t.country_code),
       t.phone, t.email, t.status, NOW()
FROM tmp_tiers t
-- evite les doublons : ajoute seulement les noms absents de la base
WHERE t.nom NOT IN (SELECT nom FROM llx_societe WHERE nom IS NOT NULL);
FIN

APRES=$($SQL $BASE -N -e "SELECT COUNT(*) FROM llx_societe;")
echo "$((APRES - AVANT)) tiers ajoutés ($APRES au total)"   # $((...)) = calcul
