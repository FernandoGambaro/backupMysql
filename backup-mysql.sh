#!/bin/bash

# ==============================================================================
# SCRIPT DE RESPALDO MYSQL PARA SISTEMAS FEDORA 43+ y PHP 8.0+
# ==============================================================================
# Autor: Adaptación basada en requerimientos de usuario.
# Descripción: Respaldo con rotación (Diario, Semanal, Mensual), verificación
#              de integridad y reportes vía s-nail (v15+).
# ==============================================================================

# --- 1. CONFIGURACIÓN ---
# Nota: El usuario y password deben estar en ~/.my.cnf para mayor seguridad.
BACKUP_DIR="$HOME/backups/mysql"
EMAIL="tu@email.com"
DBS="base_1 base_2" # Nombres de las bases de datos separados por espacio.

# Configuración de rotación: cuántas carpetas de cada tipo conservar.
KEEP_DAILY=5   # Mantiene los últimos 5 días.
KEEP_WEEKLY=4  # Mantiene las últimas 4 semanas (Sábados).
KEEP_MONTHLY=4 # Mantiene los últimos 4 meses (Día 1 de cada mes).

# --- 2. PERMISOS Y ENTORNO ---
# Establecemos umask 002 para que las carpetas y archivos tengan permisos 775/664.
# Esto permite que tu usuario normal pueda leer/borrar sin usar sudo.
umask 002

# --- 3. LÓGICA DE PERIODOS Y DIRECTORIOS ---
# Definimos la fecha con segundos para evitar colisiones en pruebas rápidas.
DATE=$(date +%Y-%m-%d_%H%M%S)
DOW=$(date +%u) # 1=Lunes, 7=Domingo.
DOM=$(date +%d) # Día del mes (01-31).

# Determinamos si el backup es mensual, semanal o diario.
if [ "$DOM" = "01" ]; then
    PERIOD="monthly"; KEEP=$KEEP_MONTHLY
elif [ "$DOW" = "6" ]; then
    PERIOD="weekly"; KEEP=$KEEP_WEEKLY
else
    PERIOD="daily"; KEEP=$KEEP_DAILY
fi

# Creamos la ruta física donde se guardará el dump.
CURRENT_DEST="$BACKUP_DIR/$PERIOD/$DATE"
mkdir -p "$CURRENT_DEST"

# Archivo temporal para ir armando el correo que recibiremos al final.
LOG_FILE="/tmp/mysql_backup_report.log"

{
  echo "================================================"
  echo " REPORTE DE RESPALDO MYSQL - $DATE"
  echo " Periodo: $PERIOD | Destino: $CURRENT_DEST"
  echo "================================================"
  printf "%-25s %-15s %-10s\n" "BASE DE DATOS" "TAMAÑO" "ESTADO"
  echo "------------------------------------------------"
} > "$LOG_FILE"

# --- 4. EJECUCIÓN DEL RESPALDO E INTEGRIDAD ---
ERROR_COUNT=0
for DB in $DBS; do
    FILE_PATH="$CURRENT_DEST/${DB}.sql.gz"
    
    # mysqldump: --single-transaction evita bloqueos en tablas InnoDB.
    # El comando gzip comprime el flujo de datos al vuelo.
    if mysqldump --single-transaction --quick --routines --triggers "$DB" | gzip > "$FILE_PATH" 2>>"$LOG_FILE"; then
        
        # VERIFICACIÓN: Buscamos la marca de tiempo al final del archivo comprimido.
        # Si 'zgrep' no la encuentra, el backup se cortó antes de tiempo.
        if zgrep -q "Dump completed on" "$FILE_PATH"; then
            SIZE=$(du -h "$FILE_PATH" | cut -f1)
            printf "%-25s %-15s %-10s\n" "$DB" "$SIZE" "[OK]" >> "$LOG_FILE"
        else
            printf "%-25s %-15s %-10s\n" "$DB" "CORRUPTO" "[FALLO]" >> "$LOG_FILE"
            ((ERROR_COUNT++))
        fi
    else
        printf "%-25s %-15s %-10s\n" "$DB" "----" "[ERROR]" >> "$LOG_FILE"
        ((ERROR_COUNT++))
    fi
done

# --- 5. ESTADO DEL ALMACENAMIENTO Y ROTACIÓN ---
{
  echo "------------------------------------------------"
  echo "ESTADO DEL ALMACENAMIENTO:"
  
  # Calculamos el peso acumulado de TODA la carpeta de respaldos.
  PESO_TOTAL=$(du -sh "$BACKUP_DIR" | cut -f1)
  echo "Uso total en disco por backups: $PESO_TOTAL"
  
  # Mostramos el espacio libre en la partición donde vive el home.
  df -h "$BACKUP_DIR" | awk 'NR==2 {print "Espacio en disco -> Usado: "$3" | Disponible: "$4}'
  
  echo "------------------------------------------------"
  echo "ROTACIÓN: Limpiando periodos antiguos en $PERIOD..."
  # 'ls -1dt */' lista carpetas por fecha descendente.
  # 'tail -n +X' selecciona las que sobran después del límite configurado.
  cd "$BACKUP_DIR/$PERIOD" && ls -1dt */ 2>/dev/null | tail -n +$((KEEP + 1)) | xargs rm -rf 2>/dev/null
  echo "Limpieza completada (Mantenidos: $KEEP)."
} >> "$LOG_FILE"

# --- 6. NOTIFICACIÓN FINAL ---
# Si hay un email configurado, enviamos el reporte completo.
if [ -n "$EMAIL" ]; then
    SUBJECT="MySQL Backup $PERIOD - Errores: $ERROR_COUNT"
    # s-nail usa la configuración del archivo /etc/s-nail.rc
    cat "$LOG_FILE" | s-nail -s "$SUBJECT" "$EMAIL"
fi

# Imprimimos el reporte en la terminal y borramos el temporal.
cat "$LOG_FILE"
rm -f "$LOG_FILE"
