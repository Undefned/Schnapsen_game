# run_scenario.py
import json, hashlib, subprocess, psycopg2, re

def sha256(path):
    return hashlib.sha256(open(path, 'rb').read()).hexdigest()

conn = psycopg2.connect(host="127.0.0.1", port=55432,
                        user="gameuser", password="schnapsen_demo",
                        dbname="schnapsen_66")
conn.autocommit = True
cur = conn.cursor()

sql = open("scenario.sql", encoding="utf-8").read()

# Разбиваем по ; (грубо, но для лабы ок)
statements = [s.strip() for s in sql.split(";") if s.strip()]

out = []
for stmt in statements:
    try:
        cur.execute(stmt)
        if cur.description:  # был SELECT
            rows = cur.fetchall()
            out.append({"query": stmt[:120], "result": rows})
        else:
            out.append({"query": stmt[:120], "result": None})
    except Exception as e:
        conn.rollback()
        out.append({"query": stmt[:120], "error": str(e)})

meta = {
    "completed_at_utc": __import__("datetime").datetime.utcnow().isoformat(),
    "steps": len(out),
    "source_sha256": {
        "schema.sql": sha256("schema.sql"),
        "functions.sql": sha256("functions.sql"),
        "scenario.sql": sha256("scenario.sql"),
    }
}
json.dump({"meta": meta, "steps": out}, open("output.json", "w", encoding="utf-8"),
          ensure_ascii=False, indent=2, default=str)
print(f"OK: {len(out)} steps -> output.json")