#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Verificación de dependencias
for pkg in jq docker; do
    if ! command -v $pkg &> /dev/null; then
        echo -e "${YELLOW}📦 Instalando dependencia: $pkg${NC}"
        sudo apt update && sudo apt install -y $pkg
    fi
done

# Verificación del plugin docker compose
if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}📦 Instalando plugin docker compose...${NC}"
    sudo apt install -y docker-compose-plugin
fi

# Verificación de imagen base
if ! docker image inspect alpine:latest &> /dev/null; then
    echo -e "${YELLOW}📦 Descargando imagen base: alpine${NC}"
    docker pull alpine
fi

# Configuración
BACKUP_DIR_ROOT="/root/backups_docker"
BACKUP_DIR_PUBLIC="/home/guquintana/backups_docker"
MOUNT_DIR="/home/guquintana/docker_volumes_mounted"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="backup_$DATE"
FULL_BACKUP_PATH="$BACKUP_DIR_ROOT/$BACKUP_NAME"

mkdir -p "$BACKUP_DIR_ROOT"
mkdir -p "$BACKUP_DIR_PUBLIC"

function backup() {
    echo -e "${CYAN}📋 Guardando lista de imágenes...${NC}"
    docker image ls --format '{{.Repository}}:{{.Tag}}' > "$FULL_BACKUP_PATH-images.txt"

    echo -e "${CYAN}📦 Exportando imágenes Docker...${NC}"
    mkdir -p "$FULL_BACKUP_PATH/images"
    while IFS= read -r image; do
        docker save "$image" -o "$FULL_BACKUP_PATH/images/$(echo $image | tr '/:' '_').tar"
    done < "$FULL_BACKUP_PATH-images.txt"

    echo -e "${CYAN}📎 Exportando volúmenes...${NC}"
    mkdir -p "$FULL_BACKUP_PATH/volumes"
    for volume in $(docker volume ls -q); do
        docker run --rm -v "$volume":/volume -v "$FULL_BACKUP_PATH/volumes":/backup alpine \
            tar -czf "/backup/${volume}.tar.gz" -C /volume . > /dev/null 2>&1
    done

    echo -e "${CYAN}🧱 Guardando contenedores activos...${NC}"
    docker ps -a --format '{{.Names}}' > "$FULL_BACKUP_PATH-containers.txt"
    for container in $(docker ps -a --format '{{.Names}}'); do
        docker inspect "$container" > "$FULL_BACKUP_PATH/${container}_inspect.json"
    done

    echo -e "${YELLOW}🔐 Ajustando permisos...${NC}"
    chown -R guquintana:guquintana "$FULL_BACKUP_PATH"

    echo -e "${YELLOW}🚚 Moviendo backup a directorio accesible desde Windows...${NC}"
    cp -r "$FULL_BACKUP_PATH" "$BACKUP_DIR_PUBLIC"
    chown -R guquintana:guquintana "$BACKUP_DIR_PUBLIC"
    chmod -R u+rwX,g+rwX,o+rX "$BACKUP_DIR_PUBLIC"

    echo -e "${GREEN}✅ Backup completado en: $FULL_BACKUP_PATH${NC}"
    echo -e "${BLUE}📁 Visible desde Windows: $BACKUP_DIR_PUBLIC/$BACKUP_NAME${NC}"
}

function recreate_containers() {
    echo -e "${CYAN}🚀 Recreando contenedores...${NC}"
    for inspect_file in "$RESTORE_TMP"/*_inspect.json; do
        container_name=$(basename "$inspect_file" _inspect.json)
        image=$(jq -r '.[0].Config.Image' "$inspect_file")

        cmd="docker run -d --name $container_name"

        ports=$(jq -r '.[0].HostConfig.PortBindings // {} | to_entries[] | "-p \(.value[0].HostPort):\(.key | split("/")[0])"' "$inspect_file")
        for port in $ports; do
            cmd+=" $port"
        done

        envs=$(jq -r '.[0].Config.Env[]?' "$inspect_file")
        for env in $envs; do
            cmd+=" -e \"$env\""
        done

        volumes=$(jq -r '.[0].Mounts[]? | "-v \(.Name):\(.Destination)"' "$inspect_file")
        for vol in $volumes; do
            cmd+=" $vol"
        done

        cmd+=" $image"
        echo "Ejecutando: $cmd"
        eval $cmd
    done
}

# (Aquí iría el resto del script que ya tienes, como restore, montar_backup_dir, montar_volumenes, menu, etc.)
