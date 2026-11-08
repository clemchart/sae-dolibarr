# Import automatisé des données CSV

[← Retour au readme](../readme.md)

## 1. Pourquoi ne pas utiliser le menu Outils ?
L'assistant d'import de Dolibarr (Outils → Assistant d'import) fonctionne, mais il demande des clics dans l'interface : il ne peut pas être scripté. On importe donc **directement dans la base de données**, en court-circuitant Dolibarr.

## 2. Analyse des tables Dolibarr
Les Tiers sont stockés dans `llx_societe` (`llx_` est le préfixe par défaut des tables Dolibarr). Structure complète relevée avec `DESCRIBE llx_societe;` : [tests/describe_llx_societe.txt](../tests/describe_llx_societe.txt).

| Colonne | Rôle |
|---|---|
| `rowid` | identifiant, auto-incrémenté |
| `nom` | raison sociale |
| `entity` | numéro de société (multi-société) : `1` |
| `client` | 0 = non, 1 = client, 2 = prospect, 3 = client + prospect |
| `fournisseur` | 0 / 1 |
| `code_client`, `code_fournisseur` | codes uniques (index unique avec `entity`), `NULL` si absent |
| `address`, `zip`, `town` | adresse |
| `fk_pays` | clé étrangère vers `llx_c_country.rowid` (FR → 1) |
| `phone`, `email` | contact |
| `status` | 1 = ouvert, 0 = fermé |
| `datec` | date de création |

## 3. Format du CSV
`data/tiers.csv`, séparateur `;`, UTF-8, une ligne d'en-tête :
```
nom;client;fournisseur;code_client;code_fournisseur;address;zip;town;country_code;phone;email;status
```
Le fichier contient 30 tiers fictifs générés par IA (autorisé par le sujet).

## 4. Méthode d'import
1. `LOAD DATA LOCAL INFILE` charge le CSV dans une **table temporaire** `tmp_tiers` (elle disparaît à la fin de la connexion).
2. `INSERT … SELECT` copie dans `llx_societe` en transformant les données :
   - code pays `FR` → `fk_pays` par une sous-requête sur `llx_c_country` ;
   - codes vides → `NULL` (`NULLIF`), sinon deux tiers sans code violeraient l'index unique ;
   - `entity = 1`, `datec = NOW()`.
3. `WHERE t.nom NOT IN (…)` ignore les tiers déjà présents : le script est **idempotent**, on peut le relancer sans doublon.

Pourquoi passer par une table temporaire plutôt que charger directement dans `llx_societe` ? Parce que `LOAD DATA` ne sait pas faire la conversion du code pays ni filtrer les doublons.

Pourquoi `LOCAL` ? Le fichier est lu par le client `mariadb` (dans le conteneur, via le montage `./data:/data:ro`) et envoyé au serveur : pas besoin du privilège `FILE` ni de régler `secure_file_priv`.

La collation de la table temporaire est lue sur `llx_societe` pour éviter l'erreur « Illegal mix of collations » lors de la comparaison des noms.

## 5. Le script `import_csv.sh`
- Utilisation : `./import_csv.sh [fichier.csv]` (fichier placé dans `data/`, `tiers.csv` par défaut)
- Étapes : vérifie que le fichier existe et que Dolibarr est installé (table `llx_societe` présente), importe, affiche le nombre de tiers ajoutés et le total.
- La version sans Docker utilisée sur la VM est dans [tests/import_csv_vm.sh](../tests/import_csv_vm.sh), la première version plus complète dans [tests/import_csv_v1.sh](../tests/import_csv_v1.sh).

## 6. Tests
| Test | Résultat attendu |
|---|---|
| Import sur une base vide | « 30 tiers ajoutés (30 au total) », visibles dans Tiers → Liste |
| Ré-import du même fichier | « 0 tiers ajoutés » |
| Fichier absent | « Fichier introuvable : data/… » |
| Dolibarr pas encore installé | « Dolibarr n'est pas installé : lance d'abord ./install.sh » |

## 7. Limites
- Les doublons sont détectés sur le nom uniquement. Un nouveau nom avec un `code_client` déjà utilisé fait échouer tout l'`INSERT` (index unique) : rien n'est importé.
- Seuls les Tiers sont importés (périmètre du POC).
