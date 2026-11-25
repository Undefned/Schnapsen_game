# run_scenario.py
import json, hashlib, psycopg2, re
from datetime import datetime, timezone

def sha256(path):
    return hashlib.sha256(open(path, 'rb').read()).hexdigest()

conn = psycopg2.connect(host="127.0.0.1", port=55432,
                        user="gameuser", password="schnapsen_demo",
                        dbname="schnapsen_66")
conn.autocommit = False
cur = conn.cursor()

sql = open("scenario.sql", encoding="utf-8").read()

# Разбиваем по ; (грубо, но для лабы ок)
# SQL comments are removed before splitting so comment-only chunks aren't sent to PostgreSQL.
sql = re.sub(r"--[^\n]*", "", sql)
statements = [s.strip() for s in sql.split(";") if s.strip()]

out = []
try:
    for stmt in statements:
        cur.execute("SAVEPOINT scenario_step")
        try:
            cur.execute(stmt)
            if cur.description:  # был SELECT
                rows = cur.fetchall()
                out.append({"query": stmt[:120], "result": rows})
            else:
                out.append({"query": stmt[:120], "result": None})
            cur.execute("RELEASE SAVEPOINT scenario_step")
        except Exception as e:
            cur.execute("ROLLBACK TO SAVEPOINT scenario_step")
            cur.execute("RELEASE SAVEPOINT scenario_step")
            out.append({"query": stmt[:120], "error": str(e)})
    
    conn.commit()  # Коммитим всю транзакцию
except Exception as e:
    conn.rollback()
    print(f"FATAL ERROR: {e}")
finally:
    cur.close()
    conn.close()

meta = {
    "completed_at_utc": datetime.now(timezone.utc).isoformat(),
    "steps": len(out),
    "source_sha256": {
        "schema.sql": sha256("schema.sql"),
        "functions.sql": sha256("functions.sql"),
        "scenario.sql": sha256("scenario.sql"),
        "sql/actions/declare_schnapsen.sql": sha256("sql/actions/declare_schnapsen.sql"),
    }
}
json.dump({"meta": meta, "steps": out}, open("output.json", "w", encoding="utf-8"),
          ensure_ascii=False, indent=2, default=str)
print(f"OK: {len(out)} steps -> output.json")
