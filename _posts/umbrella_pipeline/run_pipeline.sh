#!/bin/bash
# =============================================================================
# run_pipeline.sh
# Pipeline maestro para analizar Umbrella Sampling (ventanas n/p)
#
# Requiere que en este directorio estén:
#   - Scripts:
#       rmsd_windows.tcl
#       rmsd_us_mep-rca.Rmd
#       us_rc_overlap_np.Rmd
#       gen_metadata.sh
#       wham_rca_v6.py
#       pmf_wham_final.Rmd
#       traer_nxxx-pxxx.sh  (opcional)
#   - Archivos de entrada (*.rc y *_eq.dcd) según readme_general.txt
#
# IMPORTANTE:
#   - Usa el pandoc que trae RStudio, vía RSTUDIO_PANDOC.
# =============================================================================

set -e

LOG="pipeline.log"

# Ruta al pandoc de RStudio (obtenida con Sys.getenv('RSTUDIO_PANDOC') en RStudio)
PANDOC_BIN="/usr/lib/rstudio/resources/app/bin/quarto/bin/tools/x86_64"

timestamp() {
  date +"[%Y-%m-%d %H:%M:%S]"
}

run_step() {
  local desc="$1"
  shift

  echo "$(timestamp) >>> Paso: $desc" | tee -a "$LOG"

  # Ejecutar el comando y loguear stdout+stderr
  "$@" >> "$LOG" 2>&1
  local status=$?

  if [ $status -ne 0 ]; then
    echo "$(timestamp) !!! Error en: $desc (status $status)" | tee -a "$LOG"
    exit $status
  fi

  echo "$(timestamp) <<< Paso completado: $desc" | tee -a "$LOG"
}

echo "===============================================" | tee -a "$LOG"
echo "$(timestamp) Inicio de pipeline Umbrella RCA" | tee -a "$LOG"
echo "===============================================" | tee -a "$LOG"

# -------------------------------------------------------------------------
# Paso 0 (opcional) – Traer archivos del clúster
#   Descomenta si quieres que el pipeline también haga el scp.
# -------------------------------------------------------------------------
# if [ -x "./traer_nxxx-pxxx.sh" ]; then
#   run_step "0. Traer archivos n/p desde el clúster (traer_nxxx-pxxx.sh)" \
#     bash traer_nxxx-pxxx.sh
# else
#   echo "$(timestamp) [INFO] Saltando paso 0: traer_nxxx-pxxx.sh no es ejecutable o no existe" | tee -a "$LOG"
# fi

# -------------------------------------------------------------------------
# Paso 1 – Calcular RMSD en VMD (genera *_rmsd_PROA_DON_ACC.dat)
# -------------------------------------------------------------------------
run_step "1. Calcular RMSD en VMD (rmsd_windows.tcl)" \
  vmd -dispdev text -e rmsd_windows.tcl

# -------------------------------------------------------------------------
# Paso 2 – Analizar RMSD en R (RMarkdown -> HTML)
# -------------------------------------------------------------------------
run_step "2. Analizar RMSD en R (rmsd_us_mep-rca.Rmd)" \
  env RSTUDIO_PANDOC="$PANDOC_BIN" \
  Rscript -e "rmarkdown::render('rmsd_us_mep-rca.Rmd', quiet = TRUE)"

# -------------------------------------------------------------------------
# Paso 3 – Gráfico de solapamiento de RC (RMarkdown -> HTML)
# -------------------------------------------------------------------------
run_step "3. Generar solapamiento de RC (us_rc_overlap_np.Rmd)" \
  env RSTUDIO_PANDOC="$PANDOC_BIN" \
  Rscript -e "rmarkdown::render('us_rc_overlap_np.Rmd', quiet = TRUE)"

# -------------------------------------------------------------------------
# Paso 4 – Generar metadata_rca_n.dat (bash)
# -------------------------------------------------------------------------
run_step "4. Generar metadata desde *.rc (gen_metadata.sh)" \
  bash gen_metadata.sh

# -------------------------------------------------------------------------
# Paso 5 – Ejecutar WHAM 1D (Python)
# -------------------------------------------------------------------------
run_step "5. Ejecutar WHAM (wham_rca_v6.py)" \
  python3 wham_rca_v6.py

# -------------------------------------------------------------------------
# Paso 6 – Limpiar y suavizar PMF (RMarkdown -> HTML)
# -------------------------------------------------------------------------
run_step "6. Limpiar y suavizar PMF (pmf_wham_final.Rmd)" \
  env RSTUDIO_PANDOC="$PANDOC_BIN" \
  Rscript -e "rmarkdown::render('pmf_wham_final.Rmd', quiet = TRUE)"

# -------------------------------------------------------------------------
# Paso 7 – Mover gráficos finales a carpeta graficos_pipeline/
# -------------------------------------------------------------------------
run_step "7. Organizar gráficos finales" bash -c '
  OUTDIR="graficos_pipeline"

  mkdir -p "$OUTDIR"

  # Lista de imágenes esperadas
  FILES=(
    "US_RC_overlap_np.png"   # solapamiento RC
    "PMF_wham_n.png"         # PMF WHAM original
    "PMF_wham_n_clean.png"   # PMF limpio + spline
    "rmsd_global_prot.png"   # RMSD global proteína
    "rmsd_global_don.png"    # RMSD global donor
    "rmsd_global_acc.png"    # RMSD global acceptor
    )

  for f in "${FILES[@]}"; do
    if [ -f "$f" ]; then
      mv "$f" "$OUTDIR"/
    else
      echo "[WARN] No se encontró el archivo: $f" >> pipeline.log
    fi
  done
'

echo "===============================================" | tee -a "$LOG"
echo "$(timestamp) Pipeline completado con éxito" | tee -a "$LOG"
echo "===============================================" | tee -a "$LOG"
