# Dockerisation

[← Retour au readme](../readme.md)

## 1. Objectif
Ne plus dépendre de l'OS du serveur : Dolibarr et la base de données tournent dans des conteneurs, décrits dans un seul fichier `docker-compose.yml`. Le même dépôt s'installe à l'identique sur n'importe quelle machine qui a Docker.

## 2. Stratégies envisagées
| Option | Avantages | Inconvénients |
|---|---|---|
| 1 seul conteneur (Dolibarr + SGBD) | simple | un conteneur = un processus : mise à jour, sauvegarde et redémarrage de la base liés à ceux de l'application |
| **2 conteneurs, image Dolibarr officielle + MariaDB** | image maintenue par l'équipe Dolibarr, installation automatique au premier démarrage, modules activables par variables `DOLI_*` | dépendance à une image tierce (limitée en fixant la version) |
| 2 conteneurs, Dockerfile maison + MariaDB | maîtrise totale | il faut réécrire et maintenir l'installation de PHP, Apache, Dolibarr |

**Choix retenu : deux conteneurs, image officielle `dolibarr/dolibarr` + `mariadb:10.11`**, parce que le sujet recommande de séparer application et SGBD, et que l'image officielle fait déjà l'installation automatique (création de `conf.php`, des tables, du compte admin et de `install.lock`). Un Dockerfile maison n'apporterait rien de plus pour un POC limité aux Tiers. Le premier essai (image `latest`, MariaDB 11, valeurs en dur) est conservé dans [tests/docker-compose_essai1.yml](../tests/docker-compose_essai1.yml).

## 3. Architecture
```
               ┌───────────────────┐   réseau Docker   ┌───────────────────┐
navigateur ────┤ dolibarr-app      ├───────────────────┤ dolibarr-db       │
 :8080 → 80    │ Apache + PHP      │  (nom d'hôte "db")│ MariaDB 10.11     │
               └─────────┬─────────┘                   └─────────┬─────────┘
                         │                                       │
              volume doli_documents                      volume db_data
              (/var/www/documents)                       (/var/lib/mysql)
                                                         + ./data monté en /data (lecture seule)
```
- Seul le port de Dolibarr est publié. MariaDB (3306) n'est joignable que depuis le réseau interne créé par Compose.
- Les conteneurs se trouvent par leur nom de service (`DOLI_DB_HOST: db`) grâce au DNS interne de Docker.

## 4. Fichiers
- `docker-compose.yml`
  - `db` : image MariaDB, variables `MARIADB_*` qui créent la base et l'utilisateur au premier démarrage, `healthcheck` qui teste que InnoDB est prêt.
  - `dolibarr` : `depends_on … condition: service_healthy`, donc Dolibarr ne démarre qu'une fois la base prête ; variables `DOLI_*` pour l'installation automatique ; `DOLI_ENABLE_MODULES: Societe,Fournisseur`.
  - `restart: unless-stopped` : les conteneurs redémarrent après un reboot du serveur.
  - deux volumes nommés pour que les données survivent à la suppression des conteneurs.
- `.env.example` : modèle des variables (mots de passe, port, version). Le vrai `.env` n'est pas versionné, car il contient les mots de passe.

## 5. Le script `install.sh`
0. Se relance avec `sudo` s'il n'est pas lancé en root (installer Docker demande les droits administrateur).
1. Vérifie que Docker et Docker Compose v2 sont installés ; sinon les installe depuis le dépôt officiel Docker (Debian/Ubuntu détecté via `/etc/os-release`) et ajoute l'utilisateur au groupe `docker`.
2. Crée `.env` à partir de `.env.example` s'il n'existe pas, puis s'arrête pour qu'on change les mots de passe.
3. Lance `docker compose up -d`.
4. Attend (5 min max) qu'un compte administrateur existe dans `llx_user` : c'est le signe que Dolibarr a fini de créer ses tables.
5. Affiche l'URL d'accès.

L'étape 4 permet d'enchaîner `./install.sh && ./import_csv.sh` : sans elle, l'import échouerait car les tables n'existent pas encore.

## 6. Points d'attention
- Les variables `DB_*` et `DOLI_ADMIN_*` ne servent qu'au premier démarrage (volume vide). Pour les changer : `docker compose down -v` puis `./install.sh`.
- Fixer `DOLI_VERSION` : une sauvegarde doit être restaurée sur la même version de Dolibarr.
