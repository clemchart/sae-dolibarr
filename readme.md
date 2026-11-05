# SAE51 – Installation d'un ERP/CRM (Dolibarr)

POC de migration d'un ERP/CRM externalisé vers une instance **Dolibarr hébergée en interne**, entièrement dockerisée, avec import automatisé des tiers (clients/fournisseurs) depuis des fichiers CSV.

IUT Rouen – Réseaux & Télécoms – BUT3

| Rôle | Nom |
|---|---|
| Chef de projet | _à compléter_ |
| Membre | _à compléter_ |

---

## Architecture

Deux conteneurs séparés, orchestrés par Docker Compose :

| Service | Image | Rôle | Port |
|---|---|---|---|
| `dolibarr` | `dolibarr/dolibarr:latest` | Application web (Apache + PHP) | 8080 → 80 |
| `mariadb` | `mariadb:11` | Base de données | 3306 (interne) |

Données persistantes dans des volumes Docker :
- `dolibarr_db` : base MariaDB
- `dolibarr_docs` : documents Dolibarr
- `dolibarr_custom` : modules externes

**Choix de l'image officielle** : maintenue par l'équipe Dolibarr, installation automatique au premier démarrage et activation des modules par variables d'environnement, ce qui évite de maintenir un Dockerfile maison.

---

## Arborescence

```
sae-dolibarr/
├── docker-compose.yml   # Dolibarr + MariaDB
├── import_csv.sh        # Import automatique des tiers
├── data/
│   └── tiers.csv        # Jeu de données fictif (30 tiers)
├── docs/                # Documentation et captures
├── tests/
├── readme.md
├── suivi_projet.md      # Journal de bord
└── sources.md           # Liens et références
```

---

## Prérequis

- Debian 12 (ou toute distribution Linux)
- Docker Engine + plugin Compose (`docker compose version`)

---

## Installation

```bash
git clone <url-du-depot> sae-dolibarr
cd sae-dolibarr
docker compose up -d
docker compose logs -f dolibarr   # attendre la fin de l'installation
```

Accès : **http://\<IP-du-serveur\>:8080**

Au premier démarrage, l'installation est automatique (`DOLI_INSTALL_AUTO=1`) et les modules **Tiers, Produits, Import, Export** sont activés (`DOLI_ENABLE_MODULES`).

> ⚠️ Modifier les mots de passe `change_me_*` du `docker-compose.yml` **avant** le premier lancement.

---

## Import des données

```bash
chmod +x import_csv.sh
./import_csv.sh                 # utilise data/tiers.csv
./import_csv.sh autre_fichier.csv
```

L'assistant d'import de Dolibarr (menu **Outils**) n'étant pas automatisable, le script écrit directement dans la table `llx_societe` :

1. copie du CSV dans le conteneur MariaDB ;
2. chargement dans une table temporaire (`LOAD DATA`) ;
3. insertion dans `llx_societe` avec conversion du type et du pays ;
4. génération des codes client (`CU00001`) et fournisseur (`SU00001`).

Le script est **idempotent** : les tiers déjà présents (même nom) sont ignorés.

**Format du CSV** (séparateur `;`, UTF-8, ligne d'en-tête) :

```
nom;type;adresse;code_postal;ville;code_pays;telephone;email;site_web
```

`type` : `client` · `prospect` · `fournisseur` · `client_fournisseur`
`code_pays` : code ISO à 2 lettres (`FR`, `BE`, `CH`…)

---

## Commandes utiles

| Action | Commande |
|---|---|
| Démarrer | `docker compose up -d` |
| Arrêter | `docker compose down` |
| État des conteneurs | `docker compose ps` |
| Logs | `docker compose logs -f dolibarr` |
| Réinitialiser (⚠️ efface tout) | `docker compose down -v && docker compose up -d` |

---

## Points d'attention

- Les variables `MYSQL_*`, `DOLI_ADMIN_*` et `DOLI_ENABLE_MODULES` ne sont appliquées **qu'au premier démarrage**. Pour les modifier ensuite, il faut réinitialiser les volumes (`docker compose down -v`).
- Une erreur `Access denied` dans les logs MariaDB signifie que le volume contient une ancienne base avec d'autres identifiants.

---

## Avancement

- [x] Découverte et installation manuelle de Dolibarr
- [x] Dockerisation (Dolibarr + MariaDB)
- [x] Import manuel via le menu Outils
- [x] Script d'import automatique `import_csv.sh`
- [ ] Script d'installation unique `install.sh`
- [ ] Sauvegarde / restauration (PRA)

---

## Documentation

- [Journal de bord](suivi_projet.md)
- [Sources](sources.md)
