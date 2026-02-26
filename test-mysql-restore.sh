#!/bin/bash

# ==============================================================================
# SCRIPT DE SIMULACRO DE RESTAURACIÓN MYSQL (VERIFICACIÓN DE BACKUPS)
# ==============================================================================
# Descripción: Toma el último backup generado, lo restaura en una base de datos 
#              temporal y verifica que los datos sean legibles por el motor MySQL.
#              al finalizar borra la base temporal
# ==============================================================================

# --- 1. CONFIGURACIÓN ---
# Base de datos ficticia que se creará y borrará en cada prueba.
TEST_DB="db_prueba_restauracion"
# Carpeta donde el script buscará el archivo más reciente (usualmente daily).
BACKUP_DIR="$HOME/backups/mysql/daily"
EMAIL="tu@email.com"
# Archivo donde guardaremos los resultados técnicos del simulacro.
LOG_RESTORE="/tmp/mysql_restore_test.log"

# --- 2. LOCALIZAR EL ÚLTIMO RESPALDO ---
# 'ls -1dt' ordena directorios por fecha de modificación (el más nuevo primero).
ULTIMO_DIR=$(ls -1dt "$BACKUP_DIR"/*/ 2>/dev/null | head -n 1)
# Buscamos el archivo .gz más reciente dentro de esa carpeta.
ARCHIVO_GZ=$(ls -1t "$ULTIMO_DIR"*.sql.gz 2>/dev/null | head -n 1)

{
  echo "================================================"
  echo " SIMULACRO DE RESTAURACIÓN - $(date)"
  echo " Archivo probado: $ARCHIVO_GZ"
  echo "================================================"
} > "$LOG_RESTORE"

# Validación: Si no hay archivos, el script se detiene para evitar errores.
if [ -z "$ARCHIVO_GZ" ]; then
    echo "[ERROR] No se encontró ningún archivo .gz en $BACKUP_DIR" >> "$LOG_RESTORE"
    exit 1
fi

# --- 3. PREPARACIÓN DEL ENTORNO TEMPORAL ---
echo "Preparando base de datos temporal: $TEST_DB..." >> "$LOG_RESTORE"
# Borramos si existía una prueba previa y creamos una limpia.
# El comando 'mysql' usará las credenciales de tu ~/.my.cnf automáticamente.
mysql -e "DROP DATABASE IF EXISTS $TEST_DB; CREATE DATABASE $TEST_DB;"
# Pausa de 1 segundo para asegurar que el sistema de archivos de MariaDB registre la DB.
sleep 1

# --- 4. EJECUCIÓN DEL SIMULACRO (RESTAURACIÓN) ---
echo "Descomprimiendo y cargando datos (esto puede demorar)..." >> "$LOG_RESTORE"

# 'zcat' descomprime al vuelo y envía el SQL directamente al cliente mysql.
# '2>&1' captura tanto la salida estándar como los errores en la variable ERROR_MSG.
ERROR_MSG=$(zcat "$ARCHIVO_GZ" | mysql "$TEST_DB" 2>&1)
RET_CODE=$?

if [ $RET_CODE -eq 0 ]; then
    # Si el código de salida es 0, la estructura SQL fue procesada sin errores.
    # Contamos las tablas para confirmar que el backup no está vacío.
    TABLAS=$(mysql -sN -e "SHOW TABLES FROM $TEST_DB;" | wc -l)
    echo "[OK] Restauración exitosa." >> "$LOG_RESTORE"
    echo "     -> Se recuperaron $TABLAS tablas correctamente." >> "$LOG_RESTORE"
    
    # LIMPIEZA: Una vez verificado, borramos la base de prueba para no gastar espacio.
    mysql -e "DROP DATABASE $TEST_DB;"
    STATUS="EXITO"
else
    # Si hubo un error (permisos, sintaxis SQL, archivo cortado), lo reportamos.
    echo "[CRÍTICO] LA RESTAURACIÓN FALLÓ." >> "$LOG_RESTORE"
    echo "DETALLE DEL ERROR TÉCNICO:" >> "$LOG_RESTORE"
    echo "$ERROR_MSG" >> "$LOG_RESTORE"
    STATUS="FALLO"
fi

# --- 5. NOTIFICACIÓN Y CIERRE ---
echo "------------------------------------------------" >> "$LOG_RESTORE"
REPORT=$(cat "$LOG_RESTORE")

# El reporte se muestra en la terminal si se ejecuta manualmente.
echo "$REPORT"

# Envío del reporte por email usando la configuración moderna de s-nail.
if [ -n "$EMAIL" ]; then
    SUBJECT="Simulacro MySQL Restore ($STATUS) - $(date +%F)"
    echo "$REPORT" | s-nail -s "$SUBJECT" "$EMAIL"
fi

# Eliminamos el archivo temporal de log.
rm -f "$LOG_RESTORE"
