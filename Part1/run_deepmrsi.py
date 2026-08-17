#!/usr/bin/env python3
"""
run_deepmrsi.py — Python bridge between the MRSI pipeline and deepmrsi inference.

Called from Part1_ProcessMRSI.sh step 7 when the -Q (deep learning) flag is set:
    python run_deepmrsi.py <tmp_dir> <output_dir>

Reads NIfTI inputs produced by either:
  - MRSI_Reconstruction.m via DeepMRSI_SaveInputs.m  (MATLAB path)
  - run_julia_reco.jl via reconstruct_like_ICE        (Julia path)

from <out_path>/deepmrsi_inputs/, then calls process_deep_mrsi_offline()
from the deep_crt_mrsi package and writes NIfTI metabolite maps to <output_dir>.
"""

import json
import os
import sys
import numpy as np

# ── Parse arguments ────────────────────────────────────────────────────────────
if len(sys.argv) < 3:
    print(f"Usage: python {sys.argv[0]} <tmp_dir> <output_dir>", file=sys.stderr)
    sys.exit(1)

tmp_dir    = sys.argv[1]
output_dir = sys.argv[2]

# ── Locate inputs_dir from Parameters.mat or fall back to metadata search ─────
# Parameters.mat is a MATLAB v7.3 file (HDF5). We avoid scipy.io for v7.3 files;
# instead read out_path from deepmrsi_metadata.json which is always present.

def find_inputs_dir(tmp_dir: str) -> str:
    """Find <out_path>/deepmrsi_inputs/ by searching near tmp_dir."""
    # Try tmp_dir itself
    candidate = os.path.join(tmp_dir, "deepmrsi_inputs")
    if os.path.isdir(candidate):
        return candidate
    # Try parent of tmp_dir (common layout: out_path/tmp_*/)
    parent = os.path.dirname(tmp_dir)
    candidate = os.path.join(parent, "deepmrsi_inputs")
    if os.path.isdir(candidate):
        return candidate
    # Try reading out_path from a simple text scan of InitialParameters.m
    par_file = os.path.join(tmp_dir, "InitialParameters.m")
    if os.path.isfile(par_file):
        with open(par_file) as f:
            for line in f:
                line = line.strip()
                if line.startswith("out_path"):
                    # e.g.  out_path = '/some/path';
                    parts = line.split("=", 1)
                    if len(parts) == 2:
                        val = parts[1].strip().rstrip(";").strip().strip("'").strip('"')
                        candidate = os.path.join(val, "deepmrsi_inputs")
                        if os.path.isdir(candidate):
                            return candidate
    raise FileNotFoundError(
        f"Could not locate deepmrsi_inputs directory near tmp_dir={tmp_dir!r}. "
        "Ensure -Q was used when running Part1."
    )

inputs_dir = find_inputs_dir(tmp_dir)
print(f"run_deepmrsi: reading inputs from {inputs_dir}")

# ── Read metadata JSON ─────────────────────────────────────────────────────────
meta_path = os.path.join(inputs_dir, "deepmrsi_metadata.json")
if not os.path.isfile(meta_path):
    print(f"ERROR: deepmrsi_metadata.json not found in {inputs_dir}", file=sys.stderr)
    sys.exit(1)

with open(meta_path) as f:
    meta = json.load(f)

info = {
    "dwelltime":        meta["dwelltime"],        # ms
    "larmor_frequency": meta["larmor_frequency"], # Hz
    "inplane_res":      meta["inplane_res"],      # mm
    "fov_slice":        meta["fov_slice"],         # mm
}
# Forward any optional override keys that deepmrsi.py understands
for key in ("bet_f", "bet_g", "walinet", "lipidSuppression_beta",
            "use_prescan_for_masking", "writeWithoutSuppression",
            "makehomogeneous_sigma"):
    if key in meta:
        info[key] = meta[key]

# ── Load NIfTI inputs ─────────────────────────────────────────────────────────
try:
    import nibabel as nib
except ImportError:
    print("ERROR: nibabel not installed. Run: pip install nibabel", file=sys.stderr)
    sys.exit(1)

def load_nifti_complex(path: str) -> np.ndarray:
    """Load a NIfTI file and return a complex numpy array.

    Supports three storage conventions (same as deepmrsi.py's loader):
      1. Complex dtype (np.complex64/128)
      2. Real/imag stored as last dimension of size 2
      3. Real-valued only (treated as complex with imag=0)
    """
    img = nib.load(path)
    data = np.asarray(img.dataobj, dtype=np.float32 if img.get_data_dtype().kind == 'f' else None)
    if data is None:
        data = np.array(img.dataobj)
    if np.iscomplexobj(data):
        return data.astype(np.complex64)
    if data.shape[-1] == 2:
        return (data[..., 0] + 1j * data[..., 1]).astype(np.complex64)
    return data.astype(np.complex64)

csi_path = os.path.join(inputs_dir, "csi.nii.gz")
if not os.path.isfile(csi_path):
    print(f"ERROR: csi.nii.gz not found in {inputs_dir}", file=sys.stderr)
    sys.exit(1)
fid = load_nifti_complex(csi_path)
print(f"run_deepmrsi: fid shape = {fid.shape}")

musical_path = os.path.join(inputs_dir, "musical.nii.gz")
if not os.path.isfile(musical_path):
    print(f"ERROR: musical.nii.gz not found in {inputs_dir}", file=sys.stderr)
    sys.exit(1)
patref = load_nifti_complex(musical_path)
print(f"run_deepmrsi: patref shape = {patref.shape}")

prescan = None
prescan_path = os.path.join(inputs_dir, "prescan.nii.gz")
if os.path.isfile(prescan_path):
    prescan = load_nifti_complex(prescan_path)
    print(f"run_deepmrsi: prescan shape = {prescan.shape}")
else:
    print("run_deepmrsi: no prescan.nii.gz — deepmrsi will use patref for BET masking")

# ── Run deepmrsi ──────────────────────────────────────────────────────────────
os.makedirs(output_dir, exist_ok=True)

try:
    from deep_crt_mrsi.deepmrsi import process_deep_mrsi_offline
except ImportError as e:
    print(f"ERROR: could not import deep_crt_mrsi: {e}", file=sys.stderr)
    print("Ensure deep_crt_mrsi is installed (pip install -e /path/to/deep_crt_mrsi)", file=sys.stderr)
    sys.exit(1)

print(f"run_deepmrsi: calling process_deep_mrsi_offline → {output_dir}")
print(f"  dwelltime={info['dwelltime']} ms, larmor_frequency={info['larmor_frequency']} Hz")
print(f"  inplane_res={info['inplane_res']} mm, fov_slice={info['fov_slice']} mm")

process_deep_mrsi_offline(fid, patref, info, output_dir, uncomb_prescan=prescan)

print(f"run_deepmrsi: done. Metabolite maps written to {output_dir}")
