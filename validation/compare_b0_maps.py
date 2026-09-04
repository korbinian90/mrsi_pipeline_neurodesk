#!/usr/bin/env python3
"""Compare the field maps two reconstructions produced from the same data.

    python compare_b0_maps.py <run dir> <run dir> [...]

-A Patref is implemented twice, once in MRSI_Reconstruction.m and once in
apply_b0_patref.py, so that the MATLAB and the Julia route can be compared. Both
write the map they used to AlignFreq/B0map_Hz.raw. Two questions:

  do the estimators agree?
      Each run's map is recomputed here with deep_crt_mrsi's calculate_B0, from
      that run's OWN reference scan. Same input, so any difference is the
      estimator itself and has to be at float32 rounding.

  do the reconstructions agree?
      The written maps are then compared across runs. A difference here is a
      difference in the reference scan the two routes reconstructed, not in the
      correction, and the two numbers together say which.

Run it where deep_crt_mrsi is importable, i.e. inside the image:
    docker run --rm -v <out>:/out --entrypoint python3 <image> /out/compare_b0_maps.py /out/a /out/b
"""

import os
import sys

import h5py
import numpy as np

TOL_HZ = 1e-3


def read_written_map(run_dir, shape):
    path = os.path.join(run_dir, "AlignFreq", "B0map_Hz.raw")
    if not os.path.isfile(path):
        return None
    values = np.fromfile(path, dtype=np.float32)
    if values.size != int(np.prod(shape)):
        print(f"  {os.path.basename(run_dir)}: map has {values.size} values, "
              f"expected {int(np.prod(shape))}")
        return None
    # Both writers emit column-major, MATLAB natively and numpy on request.
    return values.reshape(shape, order="F").astype(np.float64)


def read_reference(run_dir):
    """The uncombined reference and dwelltime out of the run's CombinedCSI.mat."""
    path = os.path.join(run_dir, "CombinedCSI.mat")
    if not os.path.isfile(path):
        return None, None, None
    with h5py.File(path, "r") as f:
        if "image_FullFID/Data" not in f or "csi/RecoPar/Dwelltimes" not in f:
            return None, None, None
        raw = f["image_FullFID/Data"][()]
        dwelltime = float(np.ravel(f["csi/RecoPar/Dwelltimes"][()])[0])
        csi_shape = f["csi/Data"].shape[::-1]
    if raw.dtype.names == ("real", "imag"):
        ref = (raw["real"] + 1j * raw["imag"]).astype(np.complex64)
    else:
        ref = np.asarray(raw, dtype=np.complex64)
    return ref.transpose(range(ref.ndim)[::-1]), dwelltime, csi_shape[:3]


def main(run_dirs):
    from deep_crt_mrsi.b0_correction import calculate_B0

    failures = []
    maps = {}

    print("=== estimator, each run against calculate_B0 on its own reference ===")
    for run_dir in run_dirs:
        name = os.path.basename(os.path.normpath(run_dir))
        reference, dwelltime, shape = read_reference(run_dir)
        if reference is None:
            print(f"  {name:26s} no reference scan in CombinedCSI.mat, skipped")
            continue
        written = read_written_map(run_dir, shape)
        if written is None:
            print(f"  {name:26s} no AlignFreq/B0map_Hz.raw, so -A Patref did not run")
            continue
        maps[name] = written
        expected = np.asarray(calculate_B0(reference, dwelltime), dtype=np.float64)
        # The writer zeroes the map outside the brain mask, so only the voxels it
        # actually corrected can be compared against an unmasked recomputation.
        touched = written != 0
        if not touched.any():
            print(f"  {name:26s} the written map is all zero")
            failures.append(f"{name}: the written map is all zero")
            continue
        worst = float(np.max(np.abs(written[touched] - expected[touched])))
        ok = worst <= TOL_HZ
        print(f"  {name:26s} max |diff| {worst:.3e} Hz over {int(touched.sum())} "
              f"voxels  {'ok' if ok else 'FAIL'}")
        if not ok:
            failures.append(f"{name}: its own map differs from calculate_B0 by {worst:.3g} Hz")

    print("\n=== reconstruction, the written maps against each other ===")
    if len(maps) < 2:
        print("  fewer than two runs wrote a map, nothing to compare")
    else:
        (ref_name, reference), *rest = sorted(maps.items())
        print(f"  reference: {ref_name}  median {np.median(reference):.3f} Hz")
        for name, found in rest:
            if found.shape != reference.shape:
                print(f"  {name:26s} shape {found.shape} != {reference.shape}  FAIL")
                failures.append(f"{name}: map shape differs from {ref_name}")
                continue
            both = (found != 0) & (reference != 0)
            worst = float(np.max(np.abs(found[both] - reference[both]))) if both.any() else 0.0
            print(f"  {name:26s} max |diff| {worst:.3e} Hz over {int(both.sum())} voxels")
            print("      a difference here is the reference scan the two routes "
                  "reconstructed, not the correction")

    print()
    for line in failures:
        print(f"FAIL: {line}")
    if failures:
        return 1
    print("PASS: every run's correction matches calculate_B0 on its own reference")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1:]))
