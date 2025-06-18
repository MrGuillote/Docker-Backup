# 🐳 Docker Backup Tool

Una herramienta simple en Bash para realizar **backups completos y restauraciones** de tus entornos Docker. Ideal para entornos de desarrollo local con **WSL2 + Ubuntu**.

---

## ✅ ¿Qué hace esta herramienta?

Con un menú interactivo, este script permite:

- 🔄 **Hacer backup completo** de:
  - Imágenes Docker (`docker save`)
  - Volúmenes Docker (`tar.gz`)
  - Lista de contenedores activos
- ♻️ **Restaurar backups** fácilmente desde una lista interactiva
- 🧽 **Eliminarse automáticamente** (opcional)
- 👀 Guarda todo en una carpeta accesible desde Windows

---

## 💻 Requisitos

### 🧱 1. Tener **WSL2** instalado en Windows

Ejecutá esto desde **PowerShell con permisos de administrador**:

```powershell
wsl --install
```

> ⚠️ Esto instala WSL con Ubuntu por defecto. Puede requerir reiniciar.

### 🐧 2. Ingresá un usuario y contraseña cuando se inicie Ubuntu por primera vez

---

### 🐳 3. Instalar Docker dentro de Ubuntu (WSL)

```bash
sudo apt update
sudo apt remove docker docker-engine docker.io containerd runc -y
sudo apt install -y ca-certificates curl gnupg lsb-release

sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

---

## 🚀 Uso rápido

Abrí tu terminal de Ubuntu (WSL) y ejecutá este único comando:

```bash
[ -f Docker-Backup/docker_backup_tool.sh ] && \
(cd Docker-Backup && chmod +x docker_backup_tool.sh && ./docker_backup_tool.sh) || \
(git clone https://github.com/MrGuillote/Docker-Backup.git && cd Docker-Backup && chmod +x docker_backup_tool.sh && ./docker_backup_tool.sh)
```

> ⚙️ El script descargará el proyecto si no está, le dará permisos y lo ejecutará automáticamente.

---

## 📁 Ubicación de los backups

- 🧱 Carpeta interna (protegida):  
  `/root/backups_docker`

- 🪟 Carpeta accesible desde Windows:  
  `/home/guquintana/backups_docker`

> Accedé desde el explorador de archivos con:  
> `\\wsl.localhost\Ubuntu\home\guquintana\backups_docker`

---

## 🔄 Restaurar backup

Cuando seleccionás la opción de restaurar, se te mostrará una **lista de backups disponibles** en `/home/guquintana/backups_docker`.

El script automáticamente:

1. Copia el backup a `/root/backups_docker`
2. Restaura imágenes y volúmenes
3. Limpia el backup temporal
4. Finaliza

---

## 🧪 Menú interactivo

```text
==== DOCKER BACKUP TOOL ====
1) Hacer backup completo
2) Restaurar backup
3) Eliminar este script (auto-destruct)
4) Salir
============================
```

---

## 📦 Backup incluye:

- Todas las imágenes (`docker save`)
- Todos los volúmenes (`tar.gz`)
- Lista de contenedores activos (`docker ps -a`)
- Copia accesible para restaurar desde otra máquina

---

## ✨ Autor

Desarrollado por [MrGuillote](https://github.com/MrGuillote) 🧠  
Contribuciones y mejoras bienvenidas.

---
