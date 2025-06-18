
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
- 🔍 **Montar volúmenes Docker** automáticamente como carpetas visibles desde Windows
- 🧽 **Eliminarse automáticamente** (opcional)
- 🔁 **Resetear configuración**
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

## 🧠 ¿Qué te pide el script la primera vez?

1. 👤 **Usuario de Ubuntu** (ej: `guquintana`)
2. 📁 **Carpeta donde guardar/restaurar backups** (sugerido: `/home/guquintana/backups_docker`)
3. 🌐 **Carpeta donde montar volúmenes** (sugerido: `/home/guquintana/www-docker`)

🔐 La configuración queda guardada en `.docker_backup_config` y podés reiniciarla desde el menú.

---

## 🧪 Menú interactivo

```text
==== DOCKER BACKUP TOOL ====
1) Hacer backup completo
2) Restaurar backup
3) Montar volúmenes Docker visibles desde Windows
4) Resetear configuración
5) Eliminar este script (auto-destruct)
6) Salir
============================
```

---

## 🗃️ Backup incluye:

- Todas las imágenes (`docker save`)
- Todos los volúmenes (`tar.gz`)
- Lista de contenedores activos (`docker ps -a`)
- Copia accesible desde Windows para restaurar desde otra máquina

---

## 🔄 Restaurar backup

El script:

1. Te muestra una lista de backups disponibles
2. Copia el backup a `/root/backups_docker`
3. Restaura imágenes y volúmenes
4. Limpia temporales

---

## 🌍 Volúmenes montados visibles desde Windows

Los volúmenes son copiados a `/home/<usuario>/www-docker`, accesibles desde:

```
\\wsl.localhost\Ubuntu\home\guquintana\www-docker
```

> Así podés ver archivos de WordPress u otros volúmenes como si fueran carpetas locales.

---

## ✨ Autor

Desarrollado por [MrGuillote](https://github.com/MrGuillote) 🧠  
Contribuciones y mejoras bienvenidas.

---
