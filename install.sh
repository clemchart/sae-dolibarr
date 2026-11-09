#!/bin/bash
# Installe Dolibarr + MariaDB dans deux conteneurs Docker
cd "$(dirname "$0")"   # va dans le dossier du script ($0 = le script, dirname = son dossier)

# Se relance en root si besoin
# id -u = numéro de l'utilisateur (0 = root) ; exec = remplace ce processus par la version sudo
[ "$(id -u)" -eq 0 ] || exec sudo bash "$0" "$@"

# 1) Installe Docker s'il manque (Debian/Ubuntu)
# command -v = la commande existe ? ; >/dev/null = cache la sortie ; 2>&1 = cache aussi les erreurs
if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
    echo "1) Docker est déjà installé."
else
    echo "1) Installation de Docker..."
    . /etc/os-release              # charge les variables ID (debian) et VERSION_CODENAME (bookworm)
    apt-get update
    apt-get install -y ca-certificates curl     # -y = répond oui aux questions
    install -m 0755 -d /etc/apt/keyrings        # crée le dossier (-d) avec les droits 755 (-m)
    # curl : -f échoue si erreur HTTP, -s silencieux, -S affiche quand même les erreurs,
    #        -L suit les redirections, -o enregistre dans un fichier
    curl -fsSL "https://download.docker.com/linux/$ID/gpg" -o /etc/apt/keyrings/docker.asc
    # Ajoute le dépôt Docker ; signed-by = clé qui prouve que le dépôt est authentique
    echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$ID $VERSION_CODENAME stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || exit 1
    # usermod -aG = ajoute (-a) l'utilisateur au groupe (-G) docker ; SUDO_USER = qui a lancé sudo
    [ -n "$SUDO_USER" ] && usermod -aG docker "$SUDO_USER"
fi
systemctl start docker

# 2) Crée le .env s'il n'existe pas
if [ ! -f .env ]; then                # -f = le fichier existe ? ; ! = non
    cp .env.example .env
    [ -n "$SUDO_USER" ] && chown "$SUDO_USER" .env   # -n = non vide ; rend le fichier à l'utilisateur
    echo "2) Fichier .env créé : change les mots de passe puis relance ./install.sh"
    exit 1
fi
source .env   # charge les variables du .env dans le script

# 3) Démarre les conteneurs
echo "3) Démarrage des conteneurs..."
docker compose up -d || exit 1        # -d = en arrière-plan

# 4) Attend que le compte admin existe (5 min max)
echo -n "4) Installation de Dolibarr en cours"   # -n = pas de retour à la ligne
pret=non
for essai in $(seq 60); do            # 60 essais x 5 s = 5 minutes
    # mariadb : -N = sans nom de colonne, -e = requête à exécuter ; 2>/dev/null = cache les erreurs du début
    # grep -q '^[1-9]' = vrai si le résultat commence par 1-9, donc au moins 1 admin
    # (docker exec -e MYSQL_PWD = donne le mot de passe au conteneur)
    if docker exec -e MYSQL_PWD="$DB_ROOT_PASSWORD" dolibarr-db mariadb -uroot "$DB_NAME" -N \
         -e "SELECT COUNT(*) FROM llx_user WHERE admin=1" 2>/dev/null | grep -q '^[1-9]'; then
        pret=oui
        break
    fi
    echo -n "."
    sleep 5
done
echo
[ "$pret" = "oui" ] || { echo "Dolibarr ne répond pas : docker compose logs dolibarr"; exit 1; }

# 5) Affiche l'adresse
# hostname -I = liste des IP ; awk '{print $1}' = garde la première
echo "5) Dolibarr est prêt : http://$(hostname -I | awk '{print $1}'):$DOLI_PORT ($DOLI_ADMIN_LOGIN)"
