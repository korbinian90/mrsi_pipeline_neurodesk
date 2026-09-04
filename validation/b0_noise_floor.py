"""Is the MATLAB/Julia field map difference within the estimate's own noise?

The map is the mean of n-1 per-step phase differences, so its standard error is
computable per voxel from the scatter of those steps. That is how precisely the
field is known at all from this reference scan.

The two reconstructions see the same raw data, so their errors are correlated
and |M - J| is not two independent draws; it does not have to reach the noise
floor to be noise. What the comparison does establish is a ceiling: a difference
far below the uncertainty of the quantity being compared cannot be resolved from
this data, whatever its origin.
"""
import os
import sys

import h5py
import numpy as np


def patref(run):
    with h5py.File(os.path.join(run, "CombinedCSI.mat"), "r") as f:
        raw = f["image_FullFID/Data"][()]
        dwell = float(np.ravel(f["csi/RecoPar/Dwelltimes"][()])[0])
    a = (raw["real"] + 1j * raw["imag"]) if raw.dtype.names else np.asarray(raw)
    a = a.transpose(range(a.ndim)[::-1]).astype(np.complex128)
    if a.ndim == 4:
        a = a[..., np.newaxis]
    return a, dwell


def b0_and_sigma(ref, dwell):
    """Map in Hz and the standard error of that mean, per voxel."""
    prod = (ref[..., 1:, :] * np.conj(ref[..., :-1, :])).sum(axis=-1)
    steps = np.angle(prod)                       # (x, y, z, t-1)
    to_hz = 1.0 / (2 * np.pi) / (dwell / 1e9)
    b0 = steps.mean(axis=-1) * to_hz
    n = steps.shape[-1]
    sigma = steps.std(axis=-1, ddof=1) / np.sqrt(n) * to_hz
    signal = np.abs(ref).mean(axis=(3, 4))
    return b0, sigma, signal


m_run, j_run = sys.argv[1], sys.argv[2]
Mr, dwell = patref(m_run)
Jr, _ = patref(j_run)
print(f"reference shape {Mr.shape}, dwelltime {dwell} ns, {Mr.shape[3]} points, "
      f"{Mr.shape[4]} channels")

M, sM, sig = b0_and_sigma(Mr, dwell)
J, sJ, _ = b0_and_sigma(Jr, dwell)
diff = np.abs(M - J)
expected = np.sqrt(sM**2 + sJ**2)     # two independent estimates of one number

for frac, label in ((1.0, "all voxels"), (0.5, "top 50% signal"), (0.1, "top 10% signal")):
    cut = np.quantile(sig, 1 - frac)
    sel = sig >= cut
    d, e = diff[sel], expected[sel]
    ratio = np.median(d / np.maximum(e, 1e-12))
    print(f"  {label:14s} n={int(sel.sum()):5d}  median |M-J| {np.median(d):7.2f} Hz   "
          f"median expected noise {np.median(e):7.2f} Hz   ratio {ratio:5.2f}")
print("\n  ratio well below 1: the two reconstructions differ by less than the field")
print("  map's own uncertainty, so this data cannot resolve a difference between them.")
print("  ratio around or above 1: look for a systematic cause.")
