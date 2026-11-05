# SAE51 – Installation d'un ERP/CRM (Dolibarr)

POC de migration d'un ERP/CRM externalisé vers une instance **Dolibarr hébergée en interne**, entièrement **dockerisée**, avec **import automatisé** des tiers (clients/fournisseurs) depuis des fichiers CSV et **sauvegarde/restauration** pour un PRA.

IUT Rouen – Réseaux & Télécoms – BUT3 · Équipe : Clément, Mathis 

---

## Architecture

Deux conteneurs séparés, orchestrés par Docker Compose :

| Service | Conteneur | Image | Rôle | Port |
|---|---|---|---|---|
| `dolibarr` | `dolibarr-app` | `dolibarr/dolibarr:${DOLI_VERSION}` | Application web (Apache + PHP) | `8080` → 80 |
| `db` | `dolibarr-db` | `mariadb:10.11` | Base de données | 3306 (interne uniquement) |

Données persistantes dans des volumes Docker :

| Volume | Contenu |
|---|---|
| `db_data` | base MariaDB |
| `doli_documents` | documents Dolibarr (fichiers joints, `install.lock`) |

Le dossier `data/` est monté en lecture seule dans le conteneur MariaDB (`/data`) pour l'import CSV.

**Choix de l'image officielle** : maintenue par l'équipe Dolibarr, installation automatique au premier démarrage et activation des modules par variables d'environnement, ce qui évite de maintenir un Dockerfile maison. Voir [docs/docker.md](docs/docker.md).

**Pourquoi `install.sh` et pas seulement `docker compose up` ?** Le sujet impose un script unique. `install.sh` est une surcouche de `docker compose up` qui vérifie Docker, crée le `.env`, et surtout **attend la fin de l'installation de Dolibarr** : on peut enchaîner `./install.sh && ./import_csv.sh` sans erreur.

## Arborescence

```
sae-dolibarr/
├── install.sh           # Installation complète (Dolibarr + MariaDB)
├── import_csv.sh        # Import automatique des tiers
├── backup.sh            # Sauvegarde (base + documents + conf)
├── restore.sh           # Restauration d'une sauvegarde
├── docker-compose.yml   # Définition des 2 conteneurs
├── .env.example         # Modèle de configuration (mots de passe, port, version)
├── data/
│   └── tiers.csv        # Jeu de données fictif (30 tiers)
├── docs/                # Documentation détaillée et captures
├── tests/               # Essais (dont l'import sur la VM sans Docker)
├── readme.md
├── suivi_projet.md      # Journal de bord
└── sources.md           # Liens et références
```

## Prérequis

- Linux x86_64 ou ARM64 (testé sur **Debian 12**)
- **Docker Engine + plugin Compose v2** (`docker compose version` doit répondre)
- Accès Internet au premier lancement (téléchargement des images)
- Port `8080` libre (modifiable dans `.env`)

---

## Installation sur une machine vierge

### 1. Installer Docker (si absent)

```bash
sudo apt update && sudo apt install -y ca-certificates curl git
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER
```

Se déconnecter / reconnecter, puis vérifier :

```bash
docker --version
docker compose version
```

### 2. Récupérer le projet

```bash
git clone https://github.com/clemchart/sae-dolibarr.git
cd sae-dolibarr
```

### 3. Configurer

```bash
cp .env.example .env
nano .env
```

Changer les 3 mots de passe. **Mettre entre apostrophes simples** ceux qui contiennent des caractères spéciaux (`&`, `$`, `!`…) :

```
DB_ROOT_PASSWORD='...'
DB_PASSWORD='...'
DOLI_ADMIN_PASSWORD='...'
```

### 4. Installer

```bash
./install.sh
```

Le script vérifie Docker, lance les conteneurs, attend la fin de l'installation de Dolibarr puis affiche l'adresse d'accès.

Accès : `http://<IP-du-serveur>:8080` avec le compte `DOLI_ADMIN_LOGIN` / `DOLI_ADMIN_PASSWORD` du `.env`.

Au premier démarrage, l'installation est automatique et les modules **Tiers** et **Fournisseurs** sont activés (`DOLI_ENABLE_MODULES`).

### 5. Importer les données

```bash
./import_csv.sh                  # utilise data/tiers.csv
./import_csv.sh autre.csv        # autre fichier placé dans data/
```

---

## Import des données

L'assistant d'import de Dolibarr (menu **Outils**) n'étant pas automatisable, le script écrit directement dans la table `llx_societe` :

1. chargement du CSV dans une table temporaire (`LOAD DATA`) depuis `/data` dans le conteneur MariaDB ;
2. insertion dans `llx_societe` avec conversion du code pays (`FR` → `fk_pays`) et codes vides → `NULL` ;
3. les tiers déjà présents (même nom) sont ignorés : le script peut être relancé sans créer de doublons.

**Format du CSV** (séparateur `;`, UTF-8, ligne d'en-tête) :

```
nom;client;fournisseur;code_client;code_fournisseur;address;zip;town;country_code;phone;email;status
```

| Colonne | Valeurs |
|---|---|
| `client` | `0` non, `1` client, `2` prospect, `3` client + prospect |
| `fournisseur` | `0` / `1` |
| `country_code` | code ISO 2 lettres (`FR`, `BE`, `CH`…) |
| `status` | `1` ouvert, `0` fermé |

Détails : [docs/import.md](docs/import.md)

## Sauvegarde et restauration (PRA)

```bash
./backup.sh                              # crée backups/AAAAMMJJ-HHMMSS/
./restore.sh backups/AAAAMMJJ-HHMMSS     # restaure (confirmation demandée)
```

Une sauvegarde contient : `dolibarr.sql` (dump de la base), `documents.tar.gz` et `conf.php`.

**Procédure après incident** (serveur perdu) :

```bash
# sur le nouveau serveur, après les étapes 1 à 3 de l'installation
# + copie du dossier backups/ récupéré hors du serveur
./install.sh
./restore.sh backups/AAAAMMJJ-HHMMSS
```

Test PRA réalisé (installation → sauvegarde → `docker compose down -v` → réinstallation → restauration) : voir [docs/sauvegarde_pra.md](docs/sauvegarde_pra.md).

⚠️ Le dossier `backups/` n'est pas versionné (`.gitignore`) : il faut le copier hors du serveur pour qu'un vrai PRA soit possible.

---

## Commandes utiles

| Action | Commande |
|---|---|
| Démarrer | `docker compose up -d` |
| Arrêter | `docker compose down` |
| État des conteneurs | `docker compose ps` |
| Journaux | `docker compose logs -f dolibarr` |
| Sauvegarder | `./backup.sh` |
| Réinitialiser (⚠️ efface tout) | `docker compose down -v && ./install.sh` |

## Points d'attention

- Les variables `DB_*`, `DOLI_ADMIN_*` et `DOLI_ENABLE_MODULES` ne sont appliquées **qu'au premier démarrage**. Pour les modifier ensuite, il faut réinitialiser les volumes (`docker compose down -v`).
- Une erreur `Access denied` dans les journaux MariaDB signifie que le volume contient une ancienne base créée avec d'autres identifiants.
- Fixer `DOLI_VERSION` (ex. `24.0.2`) dans `.env` : une restauration doit se faire sur la même version de Dolibarr que la sauvegarde.
- Le `.env` contient les mots de passe : il n'est **pas** versionné.

## Avancement

- [x] Découverte et installation manuelle de Dolibarr (Debian)
- [x] Import manuel via le menu Outils
- [x] Script d'import automatique `import_csv.sh`
- [x] Dockerisation (Dolibarr + MariaDB, 2 conteneurs)
- [x] Script d'installation unique `install.sh`
- [x] Sauvegarde / restauration (PRA) testée
- [ ] Test sur une machine vierge
- [ ] Documentation détaillée dans `docs/`

## Documentation

| Fichier | Contenu |
|---|---|
| [docs/install_manuelle.md](docs/install_manuelle.md) | Installation manuelle sur Debian |
| [docs/import.md](docs/import.md) | Analyse de la base et import automatisé |
| [docs/docker.md](docs/docker.md) | Choix de la stratégie Docker |
| [docs/sauvegarde_pra.md](docs/sauvegarde_pra.md) | Sauvegarde, restauration et test PRA |
| [suivi_projet.md](suivi_projet.md) | Journal de bord |
| [sources.md](sources.md) | Sources |
