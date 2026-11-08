#!/bin/bash
# Installe Dolibarr + MariaDB dans deux conteneurs Docker
cd "$(dirname "$0")"

# Se relance en root si besoin
[ "$(id -u)" -eq 0 ] || exec sudo bash "$0" "$@"

# 1) Installe Docker s'il manque (Debian/Ubuntu)
if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
    echo "1) Docker est déjà installé."
else
    echo "1) Installation de Docker..."
    . /etc/os-release
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/$ID/gpg" -o /etc/apt/keyrings/docker.asc
    echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$ID $VERSION_CODENAME stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || exit 1
    [ -n "$SUDO_USER" ] && usermod -aG docker "$SUDO_USER"
fi
systemctl start docker

# 2) Crée le .env s'il n'existe pas
if [ ! -f .env ]; then
    cp .env.example .env
    [ -n "$SUDO_USER" ] && chown "$SUDO_USER" .env
    echo "2) Fichier .env créé : change les mots de passe puis relance ./install.sh"
    exit 1
fi
source .env

# 3) Démarre les conteneurs
echo "3) Démarrage des conteneurs..."
docker compose up -d || exit 1

# 4) Attend que le compte admin existe (5 min max)
echo -n "4) Installation de Dolibarr en cours"
pret=non
for essai in $(seq 60); do
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
echo "5) Dolibarr est prêt : http://$(hostname -I | awk '{print $1}'):$DOLI_PORT ($DOLI_ADMIN_LOGIN)"
