#!/usr/bin/env bash
# =============================================================================
# import_csv.sh : import automatisé des Tiers (clients / fournisseurs) dans Dolibarr
#
# Le CSV est chargé directement dans le SGBD, sans passer par l'interface
# Dolibarr : LOAD DATA vers une table temporaire, puis INSERT dans llx_societe.
# Les tiers déjà présents (même nom) sont ignorés, donc on peut relancer
# le script sans créer de doublons.
#
# Utilisation :
#   ./import_csv.sh                      # importe data/tiers.csv
#   ./import_csv.sh chemin/fichier.csv   # importe un autre fichier
#
# Variables d'environnement (optionnelles) :
#   DB_NAME    nom de la base Dolibarr          (défaut : dolibarr)
#   DB_ENTITY  entité Dolibarr                  (défaut : 1)
#   MYSQL_CMD  commande du client SQL           (défaut : "sudo mariadb")
#              en Docker, par exemple :
#              MYSQL_CMD="docker exec -i dolibarr-db mariadb -uroot -pXXXX"
#
# Format attendu du CSV (séparateur ;, UTF-8, 1re ligne = en-tête) :
#   nom;client;fournisseur;code_client;code_fournisseur;address;zip;town;country_code;phone;email;status
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_FILE="${1:-$SCRIPT_DIR/data/tiers.csv}"
DB_NAME="${DB_NAME:-dolibarr}"
DB_ENTITY="${DB_ENTITY:-1}"
MYSQL_CMD="${MYSQL_CMD:-sudo mariadb}"
EXPECTED_HEADER="nom;client;fournisseur;code_client;code_fournisseur;address;zip;town;country_code;phone;email;status"
IMPORT_KEY="csv$(date +%y%m%d%H%M)"   # 14 caractères max : permet de retrouver ce lot d'import

info()  { echo -e "\e[34m[INFO]\e[0m  $*"; }
ok()    { echo -e "\e[32m[OK]\e[0m    $*"; }
error() { echo -e "\e[31m[ERREUR]\e[0m $*" >&2; exit 1; }

# --- 1. Vérifications ---------------------------------------------------------
[[ -f "$CSV_FILE" ]] || error "Fichier introuvable : $CSV_FILE"
[[ -r "$CSV_FILE" ]] || error "Fichier illisible : $CSV_FILE"

header="$(head -n1 "$CSV_FILE" | tr -d '\r' | sed 's/^\xEF\xBB\xBF//')"
[[ "$header" == "$EXPECTED_HEADER" ]] || error "En-tête incorrect.
  Attendu : $EXPECTED_HEADER
  Trouvé  : $header"

nb_lignes=$(( $(grep -cv '^[[:space:]]*$' "$CSV_FILE") - 1 ))
(( nb_lignes > 0 )) || error "Le fichier ne contient aucune donnée."
info "Fichier : $CSV_FILE ($nb_lignes tiers)"

$MYSQL_CMD "$DB_NAME" -e "SELECT 1 FROM llx_societe LIMIT 1;" >/dev/null 2>&1 \
  || error "Impossible d'accéder à la table llx_societe de la base '$DB_NAME' (vérifier MYSQL_CMD / DB_NAME)."

avant=$($MYSQL_CMD "$DB_NAME" -N -e "SELECT COUNT(*) FROM llx_societe WHERE entity=$DB_ENTITY;")
info "Tiers déjà présents dans Dolibarr : $avant"

# même collation que llx_societe, sinon MariaDB refuse de comparer les noms (erreur 1267)
COLLATION=$($MYSQL_CMD "$DB_NAME" -N -e "SELECT TABLE_COLLATION FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='llx_societe';")

# --- 2. Import ------------------------------------------------------------------
# Le CSV est envoyé sur l'entrée standard (/dev/stdin) : ça marche pareil en local
# et avec "docker exec -i", sans copier le fichier dans le conteneur.
SQL="
CREATE TEMPORARY TABLE tmp_tiers (
  nom              VARCHAR(128),
  client           VARCHAR(4),
  fournisseur      VARCHAR(4),
  code_client      VARCHAR(24),
  code_fournisseur VARCHAR(24),
  address          VARCHAR(255),
  zip              VARCHAR(25),
  town             VARCHAR(50),
  country_code     VARCHAR(3),
  phone            VARCHAR(20),
  email            VARCHAR(128),
  status           VARCHAR(4)
) DEFAULT CHARSET=utf8mb4 COLLATE=$COLLATION;

LOAD DATA LOCAL INFILE '/dev/stdin'
  INTO TABLE tmp_tiers
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '\"'
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES;

-- nettoyage : fins de ligne Windows, espaces, lignes vides
UPDATE tmp_tiers SET status = TRIM(TRAILING '\r' FROM status), nom = TRIM(nom);
DELETE FROM tmp_tiers WHERE nom IS NULL OR nom = '';

INSERT INTO llx_societe
  (nom, entity, client, fournisseur, code_client, code_fournisseur,
   address, zip, town, fk_pays, phone, email, status,
   datec, fk_user_creat, import_key)
SELECT
  t.nom, $DB_ENTITY,
  CAST(NULLIF(t.client,'') AS UNSIGNED),
  CAST(NULLIF(t.fournisseur,'') AS UNSIGNED),
  NULLIF(t.code_client,''), NULLIF(t.code_fournisseur,''),
  NULLIF(t.address,''), NULLIF(t.zip,''), NULLIF(t.town,''),
  c.rowid,
  NULLIF(t.phone,''), NULLIF(t.email,''),
  COALESCE(CAST(NULLIF(t.status,'') AS UNSIGNED), 1),
  NOW(), 1, '$IMPORT_KEY'
FROM tmp_tiers t
LEFT JOIN llx_c_country c ON c.code = t.country_code
WHERE NOT EXISTS (
  SELECT 1 FROM llx_societe s WHERE s.nom = t.nom AND s.entity = $DB_ENTITY
);
"

info "Import en cours..."
$MYSQL_CMD --local-infile=1 "$DB_NAME" -e "$SQL" < "$CSV_FILE" \
  || error "L'import SQL a échoué (voir le message ci-dessus)."

# --- 3. Bilan -------------------------------------------------------------------
apres=$($MYSQL_CMD "$DB_NAME" -N -e "SELECT COUNT(*) FROM llx_societe WHERE entity=$DB_ENTITY;")
ajoutes=$(( apres - avant ))
ignores=$(( nb_lignes - ajoutes ))

ok "Import terminé : $ajoutes tiers ajoutés, $ignores ignorés (déjà présents)."
$MYSQL_CMD "$DB_NAME" -e "
SELECT COUNT(*) AS total, SUM(client IN (1,3)) AS clients, SUM(fournisseur=1) AS fournisseurs
FROM llx_societe WHERE entity=$DB_ENTITY;"
