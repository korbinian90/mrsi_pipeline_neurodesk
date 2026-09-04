#!/usr/bin/env python3
"""Check that the field correction is applied once, and measured identically.

    python check_b0_once.py <matrix_out_root> [name ...]

Two questions per configuration, both answered from what the run left behind:

  how many times was the correction applied?
      Part1 corrects when walinet_clean_csi ran with --b0, which it prints.
      deepmrsi corrects unless it was told the input already carries it, which
      run_deepmrsi.py prints, and it records the final state in meta.json.
      The count has to be 1 when -0 was given and when deepmrsi corrects on its
      own, and 0 only when nothing asked for it.

  do the runs agree on the field?
      B0map_Hz.nii.gz is derived from the same reference scan by the same code
      whichever stage applies the correction, so every run of one dataset that
      emits it must emit the same numbers. A run that differs has either read a
      different reference or scaled it differently.
"""

import json
import os
import sys

import nibabel as nib
import numpy as np

PART1_CORRECTED = "walinet_clean_csi: B0 map median"
# deepmrsi records how the FIDs it fitted came to be corrected, in the
# NIfTI-MRS ProcessingApplied shape it also writes into meta.json.
DEEPMRSI_APPLIED = "calculate_B0 + B0_correct_fids"
DEEPMRSI_INHERITED = "applied by the caller before this pipeline"


def read_log(run_dir):
    path = os.path.join(run_dir, "log.txt")
    if not os.path.isfile(path):
        return ""
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def read_meta(run_dir):
    path = os.path.join(run_dir, "deepMRSI", "meta.json")
    if not os.path.isfile(path):
        return None
    with open(path) as f:
        return json.load(f)


def b0_provenance(meta):
    """What deepmrsi says about the field correction on the FIDs it fitted."""
    for step in meta.get("ProcessingApplied", []):
        if step.get("Method") == "B0 correction":
            return step.get("Details", "")
    return ""


def corrections_applied(run_dir):
    """(count, how) or (None, why) when the run does not say."""
    log = read_log(run_dir)
    if not log:
        return None, "no log.txt"
    by_part1 = PART1_CORRECTED in log
    meta = read_meta(run_dir)
    if meta is None:
        # No deep quantification in this configuration; only Part1 could correct.
        return int(by_part1), "Part1" if by_part1 else "nothing"
    details = b0_provenance(meta)
    by_deepmrsi = details.startswith(DEEPMRSI_APPLIED)
    if by_part1 and details and not details.startswith(DEEPMRSI_INHERITED):
        # Both stages claim it, which is the shape of the double correction.
        return 2, f"Part1 + deepmrsi ({details})"
    how = " + ".join([n for n, on in (("Part1", by_part1), ("deepmrsi", by_deepmrsi)) if on])
    return int(by_part1) + int(by_deepmrsi), how or "nothing"


def expected_corrections(log):
    """What the configuration asked for, from the command line it recorded."""
    for line in log.splitlines():
        if "Part1_ProcessMRSI.sh -c " in line:
            args = line.split("Part1_ProcessMRSI.sh", 1)[1].split()
            asked = "-0" in args
            quantifies = "-Q" in args
            # deepmrsi corrects by default, so a -Q run corrects even without -0.
            return 1 if (asked or quantifies) else 0
    return None


def b0_map(run_dir):
    path = os.path.join(run_dir, "deepMRSI", "B0map_Hz.nii.gz")
    if not os.path.isfile(path):
        return None
    return np.asarray(nib.load(path).dataobj, dtype=np.float64)


def main(root, names):
    runs = names or sorted(
        n for n in os.listdir(root) if os.path.isdir(os.path.join(root, n))
    )
    failures = []
    maps = {}

    print("=== corrections applied ===")
    for name in runs:
        run_dir = os.path.join(root, name)
        count, how = corrections_applied(run_dir)
        want = expected_corrections(read_log(run_dir))
        if count is None:
            print(f"  {name:28s} skipped ({how})")
            continue
        ok = want is None or count == want
        print(f"  {name:28s} {count} ({how}), wanted {want}  {'ok' if ok else 'FAIL'}")
        if not ok:
            failures.append(f"{name}: correction applied {count} times, wanted {want}")
        found = b0_map(run_dir)
        if found is not None:
            maps[name] = found

    print("\n=== field map parity ===")
    if len(maps) < 2:
        print("  fewer than two runs emitted B0map_Hz, nothing to compare")
    else:
        reference_name, reference = sorted(maps.items())[0]
        print(f"  reference: {reference_name}  shape {reference.shape}, "
              f"median {np.median(reference):.3f} Hz")
        for name, found in sorted(maps.items())[1:]:
            if found.shape != reference.shape:
                print(f"  {name:28s} shape {found.shape} != {reference.shape}  FAIL")
                failures.append(f"{name}: B0map_Hz shape differs from {reference_name}")
                continue
            worst = float(np.max(np.abs(found - reference)))
            ok = worst <= 1e-6
            print(f"  {name:28s} max |diff| {worst:.3e} Hz  {'ok' if ok else 'FAIL'}")
            if not ok:
                failures.append(
                    f"{name}: B0map_Hz differs from {reference_name} by up to {worst:.3g} Hz"
                )

    print()
    if failures:
        for line in failures:
            print(f"FAIL: {line}")
        return 1
    print("PASS: the correction is applied once and every run measures the same field")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1], sys.argv[2:]))
