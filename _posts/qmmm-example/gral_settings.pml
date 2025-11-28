### Load molecule ###
load ex-sys-final.pdb


### Settings basics ###
set specular, 0
set depth_cue, 1
bg white
set antialias, 3
set ray_trace_mode, 3
set ligh_count, 1
set ray_opaque_background, 0
set ray_shadows, 0
set label_distance_digits, 2
set label_size, 30
set label_color, black
set dash_color, black
set dash_gap, 0.2
set dash_length, 0.3
set dash_round_ends, 1
set dash_radius, 0.02

hide all

### Selections ###
sele his, s. PROA
sele amm, s. HETA
sele wat, s. BUL*

sele 1wat, (i. 303+291+287+273+3808+1680+280+3780+1690) and (s. BUL*)

### Coloring ###
color gray, (e. c and all)

### Show ###

sh st, all

#sh sph, esferas_p
#sh st, ele h and neighbor (ele n+o) #show polar hydrogens
#hide (h. and (e. c extend 1)) #hide nonpolar H
#hide (name QQH+QQH2+QQH3)

### Settings specifics ###
show spheres, amm
set sphere_scale, 0.22, amm

#show spheres, elem H
set sphere_scale, 0.22, elem H

#show spheres, elem O
set sphere_scale, 0.22, elem O

hide st, 1wat

#set surface_color, grey, all

#set transparency, 0.5

#set sphere_color, grey

#set sphere_scale, 0.25, all
#set_bond stick_radius, 0.3, qm
#set sphere_scale, 0.2, esferas
set valence, 0
#set valence, 1 #if not, set individually
#valence guess, all
#unbond pk1, pk2
#bond pk1, pk2, 2
set_bond stick_radius, 0.22, all

### Selection distances ###
#distance r. 7KP and n. C1, r. 7KP and n. O1

### Special ###
#Example:
# transfer a piece of the molecule into a new object
#extract new_obj, chain A

# adjust trasparency for the new object
#set cartoon_transparency, 0.5, new_obj

### Set view ###
set_view (\
     0.830791712,   -0.103286304,    0.546910286,\
    -0.355970621,    0.656769574,    0.664782166,\
    -0.427854866,   -0.746982515,    0.508875191,\
     0.000000000,    0.000000000,  -28.899927139,\
     1.135551453,   -0.428874969,   -0.923106194,\
  -5445.607910156, 5503.405761719,  -20.000000000 )
