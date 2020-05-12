# Basic script to go through IMOD project directory and look for the motl.em files
# and write out the paths (and the tomogram numbers) to a text file for loading
# into Matlab

import os
import shutil
import mrcfile
import json

imod_project_dir = '/data/kshin/T4SS_sim/PDB/c4/IMOD'
look_for_dirs_starting_with = 'T4SS'

initMOTLs = []
tomonumbers = []
for folder in os.listdir(os.fsencode(imod_project_dir)):
    base = os.path.splitext(os.fsdecode(folder))[0]
    if base.startswith(look_for_dirs_starting_with):
        motl_name = ""
        for file in os.listdir(os.fsencode(imod_project_dir + "/%s"%base)):
            if os.fsdecode(file).endswith("_motl.em"):
                motl_name = os.path.basename(os.fsdecode(file))

        motl = imod_project_dir + "/%s/%s"%(base, motl_name)
        tomo_num = int(base.split("_")[-1]) + 1

        initMOTLs.append(motl)
        tomonumbers.append(tomo_num)


motl_out = "/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/motls.txt"
tomonums_out = "/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/tomonums.txt"

with open(motl_out, 'w') as f:
    f.write(' '.join(map(str, initMOTLs)) )

with open(tomonums_out, 'w') as f:
    f.write(' '.join(map(str, tomonumbers)))

print("Number of folders detected:")
print(len(initMOTLs))