Modern MySQL Backup & Verify (Fedora 43+)
Este proyecto nace de la necesidad de sustituir la herramienta clásica AutoMySQLBackup (v3.0), la cual presenta incompatibilidades con versiones modernas de Bash (5.2+), PHP 8.4 y los estándares de MariaDB/MySQL en distribuciones de vanguardia como Fedora 43.
El error recurrente line 835: 6: Bad file descriptor en scripts antiguos fue el detonante para desarrollar esta solución desde cero, priorizando la simplicidad, la seguridad de los datos y la transparencia en los reportes.
[!IMPORTANT]
DESCARGO DE RESPONSABILIDAD:
Usa estos scripts con precaución. El autor no se hace responsable por daños o pérdida de datos derivados de una mala implementación. Prueba siempre en entornos de desarrollo.
Características
Mantiene los conceptos base de AutoMySQLBackup e integra personalizaciones clave:
Rotación Inteligente: Clasificación automática en carpetas daily, weekly y monthly.
Seguridad Avanzada: Uso de archivos de credenciales (.my.cnf) para evitar exponer contraseñas en la lista de procesos del sistema.
Verificación de Integridad: Comprobación mediante zgrep de que el archivo .gz se cerró correctamente.
Simulacro de Restauración: Script complementario que recrea la base de datos en un entorno temporal para asegurar que el backup es funcional.
Reportes Modernos: Compatible con la nueva sintaxis de s-nail (v15+).
🛠️ Instalación y Configuración
1. Credenciales de acceso a MySQL (~/.my.cnf)
Para que los scripts funcionen de forma segura y sin intervención manual, crea un archivo de configuración en tu home:
bash
nano ~/.my.cnf
Usa el código con precaución.

Pega el siguiente contenido ajustando tus datos:
ini
[client]
user=tu_usuario_mysql
password="tu_password_real"
host=localhost
Usa el código con precaución.

[!IMPORTANT]
SEGURIDAD: Es obligatorio dar permisos restrictivos:
chmod 600 ~/.my.cnf
2. Configurar el Envío de Correo (s-nail)
Instala la utilidad: sudo dnf install s-nail.
En Fedora 43, s-nail utiliza una configuración modernizada. Edita el archivo global:
bash
sudo nano /etc/s-nail.rc
Usa el código con precaución.

Opción A: Sintaxis Moderna (Recomendada v15+)
Añade al final tu configuración SMTP usando la sintaxis de URL. Si tu usuario tiene @, cámbialo por %40:
ini
set mta=smtps://usuario%40dominio.com:password@smtp.tu-servidor.com:465
Usa el código con precaución.

Opción B: Sintaxis Clásica (Legacy)
Si la opción anterior falla, intenta con el formato tradicional:
ini
set smtp=smtp://tu-servidor-smtp.com:587
set smtp-auth=login
set smtp-auth-user=tu-cuenta@dominio.com
set smtp-auth-password=tu-contraseña
set from="Backup Server <tu-cuenta@dominio.com>"
set smtp-use-starttls
Usa el código con precaución.

3. Instalación de los Scripts
Descarga backup-mysql.sh y test-mysql-restore.sh en /usr/local/bin/. Luego, asigna permisos de ejecución y propiedad a tu usuario:
bash
sudo chown $USER:$USER /usr/local/bin/backup-*.sh
sudo chmod 755 /usr/local/bin/backup-*.sh
Usa el código con precaución.

Automatización (Cron)
Para que el sistema sea totalmente autónomo, añade las tareas a tu crontab:
bash
crontab -e
Usa el código con precaución.

Añade las siguientes líneas:
cron
# Todos los días a las 3:00 AM - Respaldo y Rotación
00 03 * * * /usr/local/bin/backup-mysql.sh

# Todos los domingos a las 5:00 AM - Simulacro de Restauración
00 05 * * 7 /usr/local/bin/test-mysql-restore.sh
Usa el código con precaución.

Origen del Proyecto
Este sistema fue desarrollado para resolver los fallos de redirección de descriptores de archivos en kernels y shells modernos. A diferencia de soluciones monolíticas, este enfoque separa el respaldo de la validación, permitiendo que el administrador reciba un reporte detallado no solo de que el archivo existe, sino de que los datos son 100% recuperables.
