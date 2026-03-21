import sys
from pathlib import Path

# Fix: Use standard library json/yaml logic to validate files visually
def validate_yamls():
    try:
        import yaml
    except ImportError:
        print("PyYAML not installed in Windows Python.")
        return

    base = Path(r"\\wsl$\Ubuntu\home\suhlabs\projects\suhlabs\aiops-substrate\cluster")
    errors = 0
    for p in list(base.rglob("*.yaml")) + list(base.rglob("*.yml")):
        try:
            with open(p, 'r', encoding='utf-8') as f:
                list(yaml.safe_load_all(f))
        except Exception as e:
            print(f"YAML Syntax Error in {p}:\n{e}\n")
            errors += 1
            
    print(f"YAML parsing complete. {errors} errors found.")

if __name__ == "__main__":
    validate_yamls()
