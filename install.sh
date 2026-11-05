#!/bin/bash
# Installation complète : MariaDB + Dolibarr dans deux conteneurs.
cd "$(dirname "$0")"

command -v docker >/dev/null || { echo "Docker n'est pas installé"; exit 1; }
[ -f .env ] || { cp .env.example .env; echo ".env créé : changez les mots de passe puis relancez."; exit 1; }
source .env

docker compose up -d || exit 1

# Dolibarr crée ses tables au premier démarrage : on attend que le compte admin existe
echo -n "Installation de Dolibarr en cours"
for i in $(seq 60); do
    docker exec -e MYSQL_PWD="$DB_ROOT_PASSWORD" dolibarr-db mariadb -uroot "$DB_NAME" -N \
        -e "SELECT COUNT(*) FROM llx_user WHERE admin=1" 2>/dev/null | grep -q '^[1-9]' && break
    echo -n "."; sleep 5
done
echo
[ "$i" -lt 60 ] || { echo "Dolibarr ne répond pas : voir 'docker compose logs dolibarr'"; exit 1; }

echo "Dolibarr est prêt : http://$(hostname -I | awk '{print $1}'):$DOLI_PORT ($DOLI_ADMIN_LOGIN)"
