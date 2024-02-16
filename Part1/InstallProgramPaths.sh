#!/bin/bash
##### In this file aliases and paths can be stored so that the program knows all commands.

# MATLAB Runtime (runs compiled MATLAB code without required license)
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/opt/MATLAB_Runtime_R2021b/v911/runtime/glnxa64:/opt/MATLAB_Runtime_R2021b/v911/bin/glnxa64:/opt/MATLAB_Runtime_R2021b/v911/sys/os/glnxa64:/opt/MATLAB_Runtime_R2021b/v911/sys/opengl/lib/glnxa64

# Path of compiled MATLAB functions
export Matlab_Compiled=../matlab_compiled

# Brain extraction tool (bet)
export betp=bet

# LCModel Path
export LCM_Path=lcmodel

# Run LCModel on different computer, connecting via ssh. You need a key so that you can automatically connect to this
# computer, without needing to type in the password!
# BE AWARE THAT THIS COMPUTER HAS TO BE ABLE TO ACCESS THE "LCM_Path", THE BASIS-FILE AND THE "out_path"!
RunLCModelOn=$(hostname)
export RunLCModelOn
# If you need to be a specific user on the LCModel computer. Leave empty (or dont declare it at all) if not necessary.
# export RunLCModelAs=""

# Path of local matlab for running the not_compiled version
export matlabp=matlab

# MATLAB Functions Folder for running the not_compiled version
export MatlabFunctionsFolder="/neurodesktop-storage/mrsi_processing/Part1_Reco_LCModel_MUSICAL_newREAD_vb17_7T_CSI/Matlab_Functions"
