"""Build every layer in order, and stop if a check finds bad rows.

Run from this folder, after setup.py:
    python run_sql.py
"""

import duckdb

con = duckdb.connect("data.duckdb")

# the SQL files, in the order they must run
files = [
    "02_silver/01_ddl_silver.sql",                 # silver tables
    "02_silver/02_load_silver.sql",                # bronze -> silver
    "02_silver/03_quality_checks_silver.sql",
    "03_gold/01_ddl_gold.sql",                     # gold tables: business rules
    "03_gold/02_quality_checks_gold.sql",
    "04_semantic/01_ddl_semantic.sql",             # star schema tables
    "04_semantic/02_load_semantic.sql",            # gold -> semantic
    "04_semantic/03_quality_checks_semantic.sql",
    "05_analytical/01_ddl_mart_sales.sql",         # one data mart per department
    "05_analytical/02_ddl_mart_operations.sql",
    "05_analytical/03_ddl_mart_finance.sql",
    "05_analytical/05_ddl_mart_shared.sql",        # shared lists (currency)
    "05_analytical/04_quality_checks_marts.sql",
]

for file in files:
    print("running", file)

    try:
        sql = open(file, encoding="utf-8").read()

        if "quality_checks" in file:
            # a check file: each query lists bad rows, so each one must return nothing
            for query in con.extract_statements(sql):
                bad_rows = con.execute(query).fetchall()
                if bad_rows:
                    print("CHECK FAILED:", query.query.strip())
                    print("bad rows:", bad_rows)
                    raise SystemExit(1)
        else:
            # a build file: run the whole file
            con.execute(sql)

    except (FileNotFoundError, duckdb.Error) as error:
        # a missing file or a SQL error: say which file and why, then stop
        print("ERROR in", file, ":", error)
        raise SystemExit(1)

print("done: all layers built, all checks passed")
