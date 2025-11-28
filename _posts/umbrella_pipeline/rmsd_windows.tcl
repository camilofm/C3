# ============================================================
# Script RMSD para ventanas de umbrella QM/MM
# Calcula RMSD del backbone PROA, del DON y del ACC
# para TODAS las ventanas n*** y p*** (_eq.dcd)
# ============================================================

# --- Archivos base ---
set psf_file "mep50.psf"

# Ahora incluimos tanto n*_eq.dcd como p*_eq.dcd
set dcd_patterns {n*_eq.dcd p*_eq.dcd}

# --- Selecciones exactas confirmadas por Camilo ---
set sel_prot_text "backbone and segid PROA"
set sel_don_text  "segid DON"
set sel_acc_text  "segid ACC"

# --- Función principal ---
proc calc_rmsd_three {mol sel_prot_text sel_don_text sel_acc_text outfile} {

    # Referencias (frame 0)
    set ref_prot [atomselect $mol $sel_prot_text frame 0]
    set ref_don  [atomselect $mol $sel_don_text  frame 0]
    set ref_acc  [atomselect $mol $sel_acc_text  frame 0]

    # Selecciones móviles
    set sel_prot [atomselect $mol $sel_prot_text]
    set sel_don  [atomselect $mol $sel_don_text]
    set sel_acc  [atomselect $mol $sel_acc_text]

    set nf [molinfo $mol get numframes]
    set out [open $outfile "w"]
    puts $out "# frame   rmsd_prot   rmsd_don   rmsd_acc"

    for {set i 0} {$i < $nf} {incr i} {
        $sel_prot frame $i
        $sel_don  frame $i
        $sel_acc  frame $i

        # Alinear SIEMPRE a la proteína
        set M [measure fit $sel_prot $ref_prot]
        $sel_prot move $M
        $sel_don  move $M
        $sel_acc  move $M

        # RMSDs
        set rmsd_prot [measure rmsd $sel_prot $ref_prot]
        set rmsd_don  [measure rmsd $sel_don  $ref_don]
        set rmsd_acc  [measure rmsd $sel_acc  $ref_acc]

        puts $out "$i   $rmsd_prot   $rmsd_don   $rmsd_acc"
    }

    close $out

    # limpieza
    $ref_prot delete
    $ref_don delete
    $ref_acc delete
    $sel_prot delete
    $sel_don delete
    $sel_acc delete
}

# --- Construcción de la lista de DCD (n y p) ---
set dcd_list {}

foreach pat $dcd_patterns {
    foreach dcd [glob -nocomplain $pat] {
        lappend dcd_list $dcd
    }
}

# Ordenamos por nombre, para tener n*** primero y luego p*** (o alfabéticamente)
set dcd_list [lsort $dcd_list]

if {[llength $dcd_list] == 0} {
    puts "WARNING: No se encontraron archivos n*_eq.dcd ni p*_eq.dcd en el directorio actual."
    puts "         Verifica que estás en la carpeta correcta y que los DCD existen."
}

# --- Loop sobre ventanas ---
foreach dcd $dcd_list {
    puts "Procesando $dcd ..."
    set base [file rootname $dcd]
    set outname "${base}_rmsd_PROA_DON_ACC.dat"

    mol new $psf_file type psf waitfor all
    mol addfile $dcd type dcd first 0 waitfor all

    set molid [molinfo top get id]

    calc_rmsd_three $molid $sel_prot_text $sel_don_text $sel_acc_text $outname

    mol delete $molid
}

puts "RMSD listo. Se generaron archivos *_rmsd_PROA_DON_ACC.dat para n*** y p*** (si existen)."

quit
