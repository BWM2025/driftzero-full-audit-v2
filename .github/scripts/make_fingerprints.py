import ast
import json
import sys
from pathlib import Path

if len(sys.argv) != 3:
    print("Usage: make_fingerprints.py <root_dir> <output_file>", file=sys.stderr)
    sys.exit(1)

root = Path(sys.argv[1])
out_path = Path(sys.argv[2])

result = []

for p in root.rglob("*.py"):
    # Skip macOS junk folders
    if "__MACOSX" in p.parts:
        continue

    try:
        text = p.read_text(encoding="utf-8")
    except Exception:
        try:
            text = p.read_text(encoding="latin-1")
        except Exception as e:
            result.append({"file": str(p), "error": f"read_error: {e}"})
            continue

    try:
        tree = ast.parse(text)
        classes = [n.name for n in ast.walk(tree) if isinstance(n, ast.ClassDef)]
        funcs = [n.name for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)]
        result.append({"file": str(p), "classes": classes, "functions": funcs})
    except Exception as e:
        result.append({"file": str(p), "error": f"parse_error: {e}"})

with out_path.open("w", encoding="utf-8") as f:
    json.dump(result, f, indent=2)

print(f"Fingerprinting done for {len(result)} files. Output: {out_path}")
