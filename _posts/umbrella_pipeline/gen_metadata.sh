#!/bin/bash
# ==========================================================
# Genera metadata_rca_n.dat desde los archivos *.rc
# Formato de salida:
#   filepath_rc   center
# Ejemplo:
#   n078.rc   -0.78
#   p003.rc    0.03
# ==========================================================

OUT="metadata_rca.dat"

# Vaciar output primero
: > "$OUT"

# Recorre todas las ventanas n***.rc y p***.rc
for f in n*.rc p*.rc; do
  [ -f "$f" ] || continue

  base="${f%.rc}"        # n078, p003
  prefix="${base:0:1}"   # 'n' o 'p'
  num="${base:1}"        # 078, 003, 101, 263, etc.

  # convertir a decimal: num / 100.0 (en base 10, sin octal)
  center=$(awk -v n="$num" 'BEGIN{printf "%.2f", n/100.0}')

  # signo según prefijo
  if [[ "$prefix" == "n" ]]; then
    center="-$center"
  fi

  # primera columna: nombre del archivo .rc
  printf "%s.rc\t%s\n" "$base" "$center" >> "$OUT"
done

echo "✅ Archivo generado: $OUT"

