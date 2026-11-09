# Point projet – SAE51 Dolibarr

Équipe : Clément, Mathis

## Séance 1
- Lecture du sujet et liste des livrables
- Création du dépôt `sae-dolibarr` et de l'arborescence
- Préparation de la VM Debian

## Séance 2
- Installation manuelle de Dolibarr sur Debian (Apache, PHP, MariaDB)
- Assistant d'installation web, comptes superadmin et user, activation des modules
- Import manuel du CSV via le menu Outils

## Séance 3
- Analyse de la base (`llx_societe`)
- Création de `data/tiers.csv` (30 tiers)
- Premier script d'import testé sur la VM

## Séance 4
- Dockerisation : Dolibarr + MariaDB en 2 conteneurs
- `docker-compose.yml`, `.env.example`, volumes, healthcheck

## Séance 5
- `install.sh` : installe Docker si besoin, lance les conteneurs, attend la fin de l'installation
- `import_csv.sh` : import automatique des tiers, sans doublons

## Séance 6
- `backup.sh` et `restore.sh`
- Test PRA : install, import, sauvegarde, destruction, réinstallation, restauration

## Séance 7
- Test sur machine vierge
- Finalisation de la documentation et du journal de bord
