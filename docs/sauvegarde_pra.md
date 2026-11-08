# Sauvegarde et Plan de Reprise d'Activité (PRA)

[← Retour au readme](../readme.md)

## 1. Ce qu'il faut sauvegarder
| Élément | Où | Méthode |
|---|---|---|
| Base de données | conteneur `dolibarr-db` | `mariadb-dump --single-transaction` |
| Documents (fichiers joints, logos, `install.lock`) | volume `doli_documents` | archive `tar` |
| `conf.php` (contient la clé unique de l'instance) | conteneur `dolibarr-app` | `docker cp` |
| `.env` (mots de passe) | dossier du projet | à copier à part, hors du dépôt Git |

## 2. Sauvegarde : `backup.sh`
- Utilisation : `./backup.sh`
- Produit `backups/AAAAMMJJ-HHMMSS/` avec `dolibarr.sql`, `documents.tar.gz` et `conf.php`.
- `--single-transaction` : le dump se fait dans une transaction InnoDB, cohérent sans bloquer Dolibarr.

## 3. Restauration : `restore.sh`
- Utilisation : `./restore.sh backups/AAAAMMJJ-HHMMSS` (les conteneurs doivent tourner)
- Demande confirmation, réinjecte le dump (il contient des `DROP TABLE` puis `CREATE TABLE`, donc il remplace les tables), restaure documents et `conf.php`, remet les droits `www-data`, redémarre Dolibarr et affiche le nombre de tiers.

## 4. Procédure PRA après un incident
1. Nouveau serveur Debian, `git clone` du dépôt.
2. Remettre le `.env` d'origine et le dossier `backups/` (copiés hors du serveur).
3. `./install.sh` (installe Docker si besoin, Dolibarr vierge).
4. `./restore.sh backups/AAAAMMJJ-HHMMSS`
5. Vérifier dans Dolibarr : connexion avec l'ancien compte admin, tiers présents.

## 5. Test PRA réalisé
| Étape | Commande | Résultat attendu (à confirmer lors de votre test) |
|---|---|---|
| Installation | `./install.sh` | Dolibarr accessible |
| Import | `./import_csv.sh` | 30 tiers |
| Modification | ajout d'un tiers « TEST PRA » dans l'interface | 31 tiers |
| Sauvegarde | `./backup.sh` | dossier `backups/…` créé |
| Destruction totale | `docker compose down -v` | conteneurs et volumes supprimés |
| Réinstallation | `./install.sh` | base vide |
| Restauration | `./restore.sh backups/…` | « Restauration OK : 31 tiers » |
| Vérification | interface | 30 tiers + « TEST PRA » présents ✅ |

## 6. Améliorations possibles
- Sauvegarde automatique (`cron`, par exemple tous les soirs).
- Copie automatique des sauvegardes hors du serveur (`rsync`, NAS, stockage externe) : la règle 3-2-1.
- Rotation : supprimer les sauvegardes de plus de N jours.
- Chiffrer les sauvegardes, qui contiennent des données clients.
