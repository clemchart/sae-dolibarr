# Étape 1 : installation manuelle de Dolibarr sur Debian

[← Retour au readme](../readme.md)

Objectif : comprendre le fonctionnement de Dolibarr avant d'automatiser son installation.

## 1. Environnement
- VM / conteneur : Debian XX, X Go de RAM, réseau ...
- Version de Dolibarr : XX.X.X (archive source / paquet Dolideb)

## 2. Installation des paquets
```bash
sudo apt update
sudo apt install -y apache2 default-mysql-server php php-mysql php-gd php-curl php-intl php-zip php-xml php-mbstring php-imap
sudo systemctl start mariadb
```

## 3. Configuration de MariaDB
```bash
sudo mariadb-secure-installation
mysql -u root -p
```
```sql
CREATE DATABASE dolibarr CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'dolibarr'@'localhost' IDENTIFIED BY 'XXXX';
GRANT ALL PRIVILEGES ON dolibarr.* TO 'dolibarr'@'localhost';
FLUSH PRIVILEGES;
```

## 4. Installation de Dolibarr
(commandes de téléchargement, copie dans `/var/www/`, droits `www-data`, configuration Apache)

## 5. Assistant d'installation web
Ouvrir `http://<ip>/dolibarr/install` :
1. Choix de la langue : *capture*
2. Vérification des prérequis : *capture*
3. Connexion à la base de données : *capture*
4. Création du compte **superadmin** : *capture*

## 6. Configuration après installation
- Création d'un compte **user** (Utilisateurs & Groupes) : *capture*
- Activation des modules : Tiers, Fournisseurs, ... : *capture*
- Fichier `install.lock` créé pour sécuriser l'installation

## 7. Import manuel des CSV (menu Outils)
1. Outils → Assistant d'import → Tiers
2. Choix du fichier `data/tiers.csv`
3. Correspondance des champs : *capture*
4. Résultat : X tiers importés

**Limite :** cet import est manuel et ne peut pas être automatisé, d'où l'étape suivante ([import.md](import.md)).

## 8. Problèmes rencontrés et solutions
| Problème | Cause | Solution |
|---|---|---|
| ... | ... | ... |
