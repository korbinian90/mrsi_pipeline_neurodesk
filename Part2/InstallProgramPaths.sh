#!/bin/bash
##### In this file aliases and paths can be stored so that the program knows all commands.

# Executable Paths
export matlabp='matlab'
export synthsegp=''
# export synthsegp='mri_synthseg'
export rawtomincp='rawtominc'
export minctorawp='minctoraw'
export betp='bet'
export LCM_Path='lcmodel'
export RunLCModelOn=''

# Temporary Folder
tmp_folder=$(pwd)
export tmp_folder

# Gradient Delays (measured at Vienna 7 T scanner, ~2023-10)
export DefaultGradientDelaysForCRTTrajectory="[12.562838, 12.540197, 10.082248]"

# MATLAB Runtime (runs compiled MATLAB code without required license)
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/opt/MATLAB_Runtime_R2021b/v911/runtime/glnxa64:/opt/MATLAB_Runtime_R2021b/v911/bin/glnxa64:/opt/MATLAB_Runtime_R2021b/v911/sys/os/glnxa64:/opt/MATLAB_Runtime_R2021b/v911/sys/opengl/lib/glnxa64
export MatlabCompiledFunctions="Matlab_Compiled"
