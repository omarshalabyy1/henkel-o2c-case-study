"""
O2C Analytics Engineering Case Study — One-command setup.

Usage:
    python setup.py
"""

import subprocess
import sys

# ── Step 1: install packages ──────────────────────────────────────────────────
print("Installing packages ...")
subprocess.check_call(
    [sys.executable, "-m", "pip", "install", "-q", "duckdb>=1.5.0", "pandas>=2.0"],
)

import importlib
importlib.invalidate_caches()

# ── Step 2: create the database ───────────────────────────────────────────────
import duckdb
import os
from pathlib import Path

HERE = Path(__file__).parent
DB_FILE = HERE / "data.duckdb"

print(f"\nCreating database ...")
if DB_FILE.exists():
    DB_FILE.unlink()

con = duckdb.connect(str(DB_FILE))

for sql_file in ["01_source_schema.sql", "02_sample_data.sql"]:
    print(f"  Loading {sql_file} ...")
    con.execute((HERE / "01_bronze" / sql_file).read_text(encoding="utf-8"))

tables = con.execute("SHOW TABLES").fetchall()
print(f"\nDone. {len(tables)} source tables loaded:")
for (t,) in sorted(tables):
    count = con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
    print(f"  {t:<30} {count} rows")

con.close()
