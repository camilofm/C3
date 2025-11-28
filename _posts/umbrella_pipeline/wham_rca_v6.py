#!/usr/bin/env python3
#  WHAM 1-D (estilo Alan Grossfield) – todo en kcal·mol⁻¹
#  Adaptado por Camilo – ventanas RCA (negativas y positivas, PM6/CHARMM)
#
#  v6 (mix):
#   - Basado en v4_range (la “versión buena” que ya funcionó).
#   - Compatible con ventanas n*** y p*** (metadata con centros negativos y positivos).
#   - Rango de ξ puede fijarse manualmente (XMIN_USER, XMAX_USER) o tomarse de los .rc.
#   - Nombres de salida neutros: PMF_wham_mix.*, overlap_hist_mix.png.

from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import sys

# ─── CONFIGURACIÓN ESPECÍFICA RCA ──────────────────────────────────────────

BASE_DIR  = Path("/home/camilo/Documents/Camilo/Proyecto-Fer/GgCGT/umbrella_pm6/mep_rca/results")
META_FILE = BASE_DIR / "metadata_rca.dat"   # sigue usando tu metadata actual

TEMP_K    = 298.15          # K
KCONST    = 150.0           # kcal·mol⁻¹·Å⁻² (misma para todas las ventanas)
NBINS     = 80              # nº de bins en ξ
TOL       = 1e-6            # tolerancia de convergencia WHAM
MAX_IT    = 100_000         # máximo nº de iteraciones
P_MIN     = 1e-12           # corte inferior para P_j antes de log

# RANGO MANUAL (opcional):
# Si dejas ambos en None => usa el rango observado en todos los .rc
# Modifica estos valores a tu gusto:
XMIN_USER = -3.0   # ej. -3.0  (None para automático)
XMAX_USER =  1.0   # ej.  1.0  (None para automático)

# ───────────────────────────────────────────────────────────────────────────

kB   = 0.0019872041               # kcal·mol⁻¹·K⁻¹
beta = 1.0 / (kB * TEMP_K)        # 1 / (kcal·mol⁻¹)

# 1) LEER METADATOS ---------------------------------------------------------

if not META_FILE.exists():
    sys.exit(f"[ERROR] No se encontró el archivo de metadatos: {META_FILE}")

meta = pd.read_csv(META_FILE, sep=r"\s+", header=None,
                   names=["filepath", "center"])

# Rutas relativas → absolutas (respecto a BASE_DIR)
meta["filepath"] = meta["filepath"].apply(
    lambda p: str((BASE_DIR / Path(p)).resolve())
)

# Agrega columna de kforce (misma para todas las ventanas)
meta["kforce"] = KCONST

# 1b) ESCANEO PREVIO PARA RANGO OBSERVADO ----------------------------------

obs_min, obs_max = None, None
missing_files = []

for f in meta["filepath"]:
    fpath = Path(f)
    if not fpath.exists():
        missing_files.append(str(fpath))
        continue
    try:
        xi_raw = np.loadtxt(fpath, usecols=1)
    except Exception as e:
        sys.exit(f"[ERROR] Problema leyendo {fpath}: {e}")

    if np.size(xi_raw) == 0:
        continue

    x_min_f = float(np.min(xi_raw))
    x_max_f = float(np.max(xi_raw))

    if obs_min is None or x_min_f < obs_min:
        obs_min = x_min_f
    if obs_max is None or x_max_f > obs_max:
        obs_max = x_max_f

if missing_files:
    print("[WARN] Hay archivos .rc listados en metadata que no existen:")
    for mf in missing_files:
        print("  -", mf)

if obs_min is None or obs_max is None:
    sys.exit("[ERROR] No se pudo determinar el rango observado de ξ (¿.rc vacíos?).")

print(f"[INFO] Rango observado de ξ en los .rc: {obs_min:.3f} a {obs_max:.3f} Å")

# 1c) DEFINIR RANGO PERMITIDO ----------------------------------------------

if XMIN_USER is not None and XMAX_USER is not None:
    x_min_allowed = float(XMIN_USER)
    x_max_allowed = float(XMAX_USER)
    print(f"[INFO] Usando rango definido por el usuario: {x_min_allowed:.3f} a {x_max_allowed:.3f} Å")
else:
    x_min_allowed = obs_min
    x_max_allowed = obs_max
    print(f"[INFO] Usando rango automático (observado): {x_min_allowed:.3f} a {x_max_allowed:.3f} Å")

if x_min_allowed >= x_max_allowed:
    sys.exit("[ERROR] Rango inválido: x_min >= x_max")

# 2) CARGAR ξ (YA CON EL RANGO DEFINIDO) -----------------------------------

xi_series, n_i = [], []
xi_min_list, xi_max_list = [], []

for f in meta["filepath"]:
    fpath = Path(f)
    if not fpath.exists():
        sys.exit(f"[ERROR] No existe el archivo de RC: {fpath}")

    xi_raw = np.loadtxt(fpath, usecols=1)

    # Restringir al rango permitido (ya definido arriba)
    xi = xi_raw[(xi_raw >= x_min_allowed) & (xi_raw <= x_max_allowed)]

    if np.size(xi) == 0:
        sys.exit(f"[ERROR] Todas las muestras de {fpath} quedaron fuera del rango permitido; revisa el rango o los datos.")

    xi_series.append(xi)
    n_i.append(len(xi))
    xi_min_list.append(float(np.min(xi)))
    xi_max_list.append(float(np.max(xi)))

n_i  = np.asarray(n_i, dtype=float)       # nº de muestras por ventana
Ntot = float(n_i.sum())
print(f"[INFO] Ventanas leídas: {len(meta)}, muestras totales (filtradas): {int(Ntot)}")
print(f"[INFO] Rango real de ξ tras filtro: {min(xi_min_list):.3f} a {max(xi_max_list):.3f} Å")

# 2b) DIAGNÓSTICO DE SOLAPAMIENTO ------------------------------------------

plt.figure(figsize=(6, 4))
for xi in xi_series:
    plt.hist(xi, bins=50, alpha=0.3, density=True)
plt.title("Solapamiento entre ventanas (histograma bruto)")
plt.xlabel(r"ξ (Å)")
plt.ylabel("Densidad")
plt.tight_layout()
plt.savefig(BASE_DIR / "overlap_hist_mix.png", dpi=300)
plt.close()

# 3) HISTOGRAMAS ------------------------------------------------------------

all_xi  = np.concatenate(xi_series)
edges   = np.linspace(all_xi.min(), all_xi.max(), NBINS + 1)
centers = 0.5 * (edges[:-1] + edges[1:])
hist    = np.array([np.histogram(xi, bins=edges)[0] for xi in xi_series], float)

n_ij = hist
n_i[n_i == 0] = 1.0                      # evita división por cero

# TOTAL de conteos por bin
N_j = n_ij.sum(axis=0)

# Máscara de bins con al menos una muestra
mask = N_j > 0
if not np.any(mask):
    sys.exit("[ERROR] Todos los bins quedaron vacíos; revisa NBINS o los datos.")

centers = centers[mask]
n_ij    = n_ij[:, mask]
N_j     = N_j[mask]

print(f"[INFO] Bins usados en WHAM: {len(centers)} (de {NBINS} originales)")

# Matriz de bias V_{ij} (kcal·mol⁻¹), solo para bins usados
centers_mat = centers[None, :]                    # shape (1, B_eff)
centers_mat = np.repeat(centers_mat, len(meta), axis=0)
V_ij = 0.5 * meta["kforce"].values[:, None] * (centers_mat - meta["center"].values[:, None])**2

# 4) WHAM (Ecs. 8 y 9) ------------------------------------------------------

f_i = np.zeros(len(meta))               # f_i ≡ F_i/(kBT)  (adimensional)

for it in range(MAX_IT):
    # (a)   P_j  =  Σ_i n_ij / Σ_i n_i exp(f_i - βV_ij)
    denom = np.sum(n_i[:, None] * np.exp(f_i[:, None] - beta * V_ij), axis=0)

    # Evitar división por cero
    zero_mask = denom <= 0.0
    if np.any(zero_mask):
        denom[zero_mask] = np.inf

    P_j = np.sum(n_ij, axis=0) / denom

    # Corte inferior para evitar probabilidades 0
    P_j[P_j < P_MIN] = P_MIN
    P_j /= P_j.sum()                   # normaliza Σ_j P_j = 1

    # (b)   f_i ← - ln Σ_j P_j exp(-β V_ij)
    exp_term = np.exp(-beta * V_ij)     # shape (W,B_eff)
    sum_term = np.sum(P_j[None, :] * exp_term, axis=1)

    eps = 1e-300
    sum_term[sum_term < eps] = eps

    f_new = -np.log(sum_term)

    if np.max(np.abs(f_new - f_i)) < TOL:
        print(f"[WHAM] Convergió tras {it} iteraciones")
        break

    f_i = f_new
else:
    print("[WHAM] No convergió en el límite actual de iteraciones")

# 5) PERFIL DE ENERGÍA LIBRE ------------------------------------------------

G = -kB * TEMP_K * np.log(P_j)          # kcal·mol⁻¹
G -= G.min()                            # referencia 0 en el mínimo

pmf_df = pd.DataFrame({"xi": centers, "PMF_kcal_mol": G})
pmf_csv = BASE_DIR / "PMF_wham_mix.csv"
pmf_png = BASE_DIR / "PMF_wham_mix.png"

pmf_df.to_csv(pmf_csv, index=False)

plt.figure()
plt.plot(centers, G, lw=1.2)
plt.xlabel(r"Coordenada de reacción ξ (Å)")
plt.ylabel(r"ΔG(ξ)  [kcal·mol$^{-1}$]")
plt.title("Perfil de Energía Libre (WHAM, ventanas umbrella RCA)")
plt.tight_layout()
plt.savefig(pmf_png, dpi=300)
plt.close()

print("[OK] Generados:")
print(f"   {BASE_DIR / 'overlap_hist_mix.png'}")
print(f"   {pmf_csv}")
print(f"   {pmf_png}")
