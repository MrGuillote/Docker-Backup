#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración de backup interno
BACKUP_DIR_ROOT="/root/backups_docker"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="backup_$DATE"

# Verificar y/o instalar zenity si se desea soporte gráfico
function ensure_zenity_installed() {
    if ! command -v zenity &> /dev/null; then
        echo -e "${YELLOW}🔍 Zenity no está instalado. Instalando...${NC}"
        sudo apt update && sudo apt install -y zenity
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Zenity instalado correctamente.${NC}"
        else
            echo -e "${RED}❌ Error al instalar zenity.${NC}"
        fi
    fi
}

# Función para convertir rutas de Windows a WSL
function fix_windows_path() {
    local path="$1"
    path="${path//'\\'/'/'}"  # Reemplaza \ por /
    if [[ "$path" =~ ^[A-Za-z]: ]]; then
        local drive_letter="${path:0:1}"
        local rest="${path:2}"
        path="/mnt/${drive_letter,,}/${rest}"
        path="${path// /}" # Elimina espacios
        path="${path//\"}" # Elimina comillas
    fi
    echo "$path"
}

function confirm_path() {
    local final_path="$1"
    echo -ne "${YELLOW}📂 ¿Usamos esta ruta? ${BLUE}$final_path${YELLOW} [s/N]: ${NC}"
    read confirm
    if [[ "$confirm" =~ ^[Ss]$ ]]; then
        return 0
    else
        echo -e "${RED}🚫 Ruta cancelada por el usuario.${NC}"
        return 1
    fi
}

function backup() {
    echo -ne "${CYAN}📁 ¿Dónde querés guardar el backup? (ej. /home/usuario/backups o D:\\Users\\usuario\\Downloads): ${NC}"
    read dest_dir_raw
    dest_dir=$(fix_windows_path "$dest_dir_raw")
    echo -e "${YELLOW}📂 Ruta convertida a WSL: ${BLUE}$dest_dir${NC}"

    if ! confirm_path "$dest_dir"; then
        return
    fi

    if [ ! -d "$dest_dir" ]; then
        echo -e "${YELLOW}📂 La ruta no existe. Creando: $dest_dir${NC}"
        mkdir -p "$dest_dir"
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Error al crear el directorio de destino${NC}"
            return
        fi
    fi

    mkdir -p "$BACKUP_DIR_ROOT"
    FULL_BACKUP_PATH="$BACKUP_DIR_ROOT/$BACKUP_NAME"

    echo -e "${CYAN}📋 Guardando lista de imágenes...${NC}"
    docker image ls --format '{{.Repository}}:{{.Tag}}' > "$FULL_BACKUP_PATH-images.txt"

    echo -e "${CYAN}📦 Exportando imágenes Docker...${NC}"
    mkdir -p "$FULL_BACKUP_PATH/images"
    while IFS= read -r image; do
        docker save "$image" -o "$FULL_BACKUP_PATH/images/$(echo $image | tr '/:' '_').tar"
    done < "$FULL_BACKUP_PATH-images.txt"

    echo -e "${CYAN}💾 Exportando volúmenes...${NC}"
    mkdir -p "$FULL_BACKUP_PATH/volumes"
    for volume in $(docker volume ls -q); do
        docker run --rm -v "$volume":/volume -v "$FULL_BACKUP_PATH/volumes":/backup alpine \
            tar -czf "/backup/${volume}.tar.gz" -C /volume . > /dev/null 2>&1
    done

    echo -e "${CYAN}🧱 Guardando contenedores activos...${NC}"
    docker ps -a --format '{{.Names}}' > "$FULL_BACKUP_PATH-containers.txt"

    echo -e "${YELLOW}🚚 Moviendo backup a directorio accesible...${NC}"
    cp -r "$FULL_BACKUP_PATH" "$dest_dir"

    echo -e "${GREEN}✅ Backup completado en: $FULL_BACKUP_PATH${NC}"
    echo -e "${BLUE}📁 Visible desde: $dest_dir/$BACKUP_NAME${NC}"
}

function menu() {
    ensure_zenity_installed
    echo -e "\n${BLUE}==== DOCKER BACKUP TOOL ====${NC}"
    echo -e "${YELLOW}1)${NC} Hacer backup completo"
    echo -e "${YELLOW}2)${NC} Restaurar backup"
    echo -e "${YELLOW}3)${NC} Montar volúmenes"
    echo -e "${YELLOW}4)${NC} Salir"
    echo -e "${BLUE}============================${NC}"
    echo -ne "${CYAN}Selecciona una opción: ${NC}"
    read opcion
    case $opcion in
        1) backup ;;
        2) echo -e "${RED}⚠️ Restauración aún no implementada aquí${NC}" ;;
        3) echo -e "${RED}⚠️ Montaje aún no implementado aquí${NC}" ;;
        4) echo -e "${GREEN}👋 Saliendo...${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Opción no válida${NC}"; menu ;;
    esac
}

menu
