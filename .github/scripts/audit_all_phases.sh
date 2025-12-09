#!/usr/bin/env bash
set -euo pipefail

# All your phase zips (no .zip extension here)
PHASES=("phase-1" "phase-2a" "phase-2b" "phase-4" "phase-5" "phase-6" "phase-8")

# Clean workspace
rm -rf audit_work
mkdir audit_work

for phase in "${PHASES[@]}"; do
  zip="${phase}.zip"
  workdir="audit_work/${phase}"

  echo "=== Processing ${zip} ==="

  if [ ! -f "$zip" ]; then
    echo "WARNING: ${zip} not found in repo root, skipping" >&2
    continue
  fi

  rm -rf "$workdir"
  mkdir -p "$workdir"

  # Unzip this phase into its workdir
  unzip -o "$zip" -d "$workdir"

  # Generate manifest + filelist, ignoring macOS junk
  (
    cd "$workdir"
    find . -type f ! -path "*__MACOSX*" -exec sha256sum {} \; | sort > "../../manifest_${phase}.txt"
    find . -type f ! -path "*__MACOSX*" | sort > "../../filelist_${phase}.txt"
  )

  # Generate fingerprints JSON for this phase (classes/functions per .py)
  python3 .github/scripts/make_fingerprints.py "$workdir" "fingerprints_${phase}.json"

  # Try to run Deadly10 tests if they exist
  if [ -d "$workdir/test_harness/deadly10" ]; then
    echo "Running Deadly10 tests for ${phase}"
    (
      cd "$workdir"
      # Try to install deps if requirements.txt exists
      if [ -f "requirements.txt" ]; then
        python3 -m pip install -r requirements.txt || echo "requirements install failed" >> "../../tests_${phase}.log"
      fi
      # Run pytest on Deadly10; don't kill the whole job if tests fail
      python3 -m pytest test_harness/deadly10 -q > "../../tests_${phase}.log" 2>&1 || echo "tests failed (see log)" >> "../../tests_${phase}.log"
    )
  else
    echo "No Deadly10 tests found for ${phase}" > "tests_${phase}.log"
  fi

done

echo "All phases processed."
