**Modern MySQL Backup & Verify Fedora 43+ PHP 8.0+**

Este proyecto nace de la necesidad de sustituir la herramienta AutoMySQLBackup (v3.0), la cuale presenta incompatibilidades con las versiones modernas de Bash (5.2+), PHP 8.0 y los nuevos estándares de MariaDB/MySQL en distribuciones vanguardistas como Fedora 43.
El error común line 835: 6: Bad file descriptor en scripts antiguos fue el detonante para desarrollar esta solución desde cero, priorizando la simplicidad, la seguridad de los datos y la transparencia en los reportes.

> [!IMPORTANT]
> NOTA:
> Usa todos los códigos con precaución, no soy responsable por daños que pueda causar una mala implementación.

Características
Mantiene conceptos base de AutoMySQLBackup y le agregue algunas personalizaciones ;-)
* Rotación Inteligente: Clasificación automática en daily, weekly y monthly.
* Seguridad: Uso de archivos de credenciales cifrados para evitar exponer contraseñas en procesos del sistema.
* Integridad: Verificación bit a bit de que el archivo .gz terminó correctamente.
* Simulacro de Restauración: Script complementario que recrea la base de datos en un entorno temporal para asegurar que el backup es funcional.
* Reportes Modernos: Compatible con la nueva sintaxis de s-nail (v15+).

**Instalación y Configuración**
***1. Credenciales de acceso a mysql (~/.my.cnf)***
Para que los scripts funcionen sin pedir contraseña y de forma segura, crea un archivo de configuración en tu home:
bash
nano ~/.my.cnf

Pega el siguiente contenido:
ini
[client]
user=tu_usuario_mysql
password="tu_password_real"
host=localhost
Usa el código con precaución.

***Importante:*** Dale permisos restrictivos: chmod 600 ~/.my.cnf

***2. Configurar el Envío de Correo (s-nail) (sudo dnf install s-nail)***
En Fedora 43, s-nail ha modernizado su configuración. Edita el archivo global:
bash
sudo nano /etc/s-nail.rc

Añade al final tu configuración SMTP usando la sintaxis de URL (v15+):
ini
# Si tu usuario tiene '@', cámbialo por '%40'
set mta=smtps://usuario%40dominio.com:password@smtp.tu-servidor.com:465
////////////////////////////
*Puede que no te funcione esa configuración, puedes usar esta otra*
set smtp=smtp://tu-servidor-smtp.com:587
set smtp-auth=login
set smtp-auth-user=tu-cuenta@dominio.com
set smtp-auth-password=tu-contraseña
set from="Backup Server <tu-cuenta@dominio.com>"
set smtp-use-starttls


***3. Instalación de los Scripts***
Descarga backup-mysql.sh y test-mysql-restore.sh en /usr/local/bin/.
Asigna permisos de ejecución y propiedad a tu usuario:
bash
sudo chown $USER:$USER /usr/local/bin/backup-*.sh
sudo chmod 755 /usr/local/bin/backup-*.sh

Automatización (Cron)
Para que el sistema sea totalmente autónomo, añade las tareas a tu crontab:
bash
crontab -e

cron
# Todos los días a las 3:00 AM - Respaldo y Rotación
00 03 * * * /usr/local/bin/backup-mysql.sh

# Todos los domingos a las 5:00 AM - Simulacro de Restauración
00 05 * * 7 /usr/local/bin/test-mysql-restore.sh

Origen del Proyecto
Este script fue desarrollado para resolver los fallos de redirección de descriptores de archivos en sistemas modernos. A diferencia de soluciones monolíticas, este enfoque separa el respaldo de la validación, permitiendo que el administrador reciba un reporte detallado no solo de que el archivo existe, sino de que los datos son recuperables.
