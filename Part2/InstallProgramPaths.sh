#!/bin/bash
##### In this file aliases and paths can be stored so that the program knows all commands.

##### The following programs are necessary:
##### -- Minc
##### -- MATLAB
##### -- tar 						(Any version should work)
##### -- gzip						(Any version should work)
##### -- gunzip						(Any version should work)

# Executable Paths
export matlabp='matlab'
export synthsegp='' # deactivate synthseg
# export synthsegp='mri_synthseg' # optional

export rawtomincp='rawtominc'
export minctorawp='minctoraw'

# Temporary Folder
tmp_trunk="$(pwd)/tmp"
export tmp_trunk

# MATLAB Runtime (runs compiled MATLAB code without required license)
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/opt/MATLAB_Runtime_R2021b/v911/runtime/glnxa64:/opt/MATLAB_Runtime_R2021b/v911/bin/glnxa64:/opt/MATLAB_Runtime_R2021b/v911/sys/os/glnxa64:/opt/MATLAB_Runtime_R2021b/v911/sys/opengl/lib/glnxa64
export MatlabCompiledFunctions="Matlab_Compiled"
