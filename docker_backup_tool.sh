#!/bin/bash

# Configuración
BACKUP_DIR_ROOT="/root/backups_docker"
BACKUP_DIR_PUBLIC="/home/guquintana/backups_docker"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="backup_$DATE"
FULL_BACKUP_PATH="$BACKUP_DIR_ROOT/$BACKUP_NAME"

mkdir -p "$BACKUP_DIR_ROOT"
mkdir -p "$BACKUP_DIR_PUBLIC"

function backup() {
    echo "📋 Guardando lista de imágenes..."
    docker image ls --format '{{.Repository}}:{{.Tag}}' > "$FULL_BACKUP_PATH-images.txt"

    echo "📦 Exportando imágenes Docker..."
    mkdir -p "$FULL_BACKUP_PATH/images"
    while IFS= read -r image; do
        docker save "$image" -o "$FULL_BACKUP_PATH/images/$(echo $image | tr '/:' '_').tar"
    done < "$FULL_BACKUP_PATH-images.txt"

    echo "💾 Exportando volúmenes..."
    mkdir -p "$FULL_BACKUP_PATH/volumes"
    for volume in $(docker volume ls -q); do
        docker run --rm -v "$volume":/volume -v "$FULL_BACKUP_PATH/volumes":/backup alpine \
            tar -czf "/backup/${volume}.tar.gz" -C /volume . > /dev/null 2>&1
    done

    echo "🧱 Guardando contenedores activos..."
    docker ps -a --format '{{.Names}}' > "$FULL_BACKUP_PATH-containers.txt"

    echo "🚚 Moviendo backup a directorio accesible desde Windows..."
    cp -r "$FULL_BACKUP_PATH" "$BACKUP_DIR_PUBLIC"

    echo "✅ Backup completado en: $FULL_BACKUP_PATH"
    echo "📁 Visible desde Windows: $BACKUP_DIR_PUBLIC/$BACKUP_NAME"
}

function restore() {
    echo "📂 Backups disponibles en: $BACKUP_DIR_PUBLIC"
    mapfile -t backups < <(ls -1 "$BACKUP_DIR_PUBLIC")

    if [ ${#backups[@]} -eq 0 ]; then
        echo "❌ No hay backups disponibles."
        return
    fi

    echo ""
    echo "Seleccione el backup a restaurar:"
    for i in "${!backups[@]}"; do
        echo "$((i+1))) ${backups[$i]}"
    done

    echo -n "📝 Ingrese el número del backup: "
    read option

    index=$((option-1))
    if [[ $index -lt 0 || $index -ge ${#backups[@]} ]]; then
        echo "❌ Opción inválida."
        return
    fi

    RESTORE_NAME="${backups[$index]}"
    RESTORE_SRC="$BACKUP_DIR_PUBLIC/$RESTORE_NAME"
    RESTORE_TMP="$BACKUP_DIR_ROOT/$RESTORE_NAME"

    echo "📥 Copiando backup a $BACKUP_DIR_ROOT..."
    cp -r "$RESTORE_SRC" "$BACKUP_DIR_ROOT"

    echo "📦 Restaurando imágenes..."
    for tarfile in "$RESTORE_TMP/images/"*.tar; do
        docker load -i "$tarfile"
    done

    echo "💾 Restaurando volúmenes..."
    for volume_archive in "$RESTORE_TMP/volumes/"*.tar.gz; do
        volume_name=$(basename "$volume_archive" .tar.gz)
        docker volume create "$volume_name"
        docker run --rm -v "$volume_name":/volume -v "$RESTORE_TMP/volumes":/backup alpine \
            sh -c "cd /volume && tar -xzf /backup/$volume_name.tar.gz"
    done

    echo "🧹 Limpiando archivos temporales..."
    rm -rf "$RESTORE_TMP"

    echo "✅ Restauración completada."
}

function menu() {
    echo ""
    echo "==== DOCKER BACKUP TOOL ===="
    echo "1) Hacer backup completo"
    echo "2) Restaurar backup"
    echo "3) Salir"
    echo "============================"
    echo -n "Selecciona una opción: "
    read opcion
    case $opcion in
        1) backup ;;
        2) restore ;;
        3) exit 0 ;;
        *) echo "❌ Opción no válida"; menu ;;
    esac
}

menu
