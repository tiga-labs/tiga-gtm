# Enrich a Local File with LinkedIn Data

Append LinkedIn profile data to each row of a user-provided CSV/TSV/Excel/JSON file of people. No Tiga list is involved — the output is the same file shape with LinkedIn columns added.

## Steps

1. **Inspect the file** — preview the first few rows to understand its shape:
```python
import pandas as pd
df = pd.read_csv("./people.csv", nrows=5)
print(df.columns.tolist())
print(df.head())
```

2. **Confirm the LinkedIn URL column.** It's usually named `linkedin_url`, `linkedin`, `profile_url`, or `li_url`. If it's ambiguous or missing, ask the user: *"Which column contains the LinkedIn URLs?"* Do not proceed without a confirmed URL column. A valid LinkedIn URL looks like `www.linkedin.com/in/<profile_id>`.

3. **Write and run the enrichment script.** Reduce logging to conserve tokens — print a simple progress line every 25 records:

```python
import csv
import os
import requests

API_KEY = os.environ["TIGA_API_KEY"]
BASE_URL = os.environ.get("TIGA_BASE", "https://app.tigalabs.com")
INPUT_FILE = "people.csv"
OUTPUT_FILE = "people_enriched.csv"

def get_linkedin_profile(linkedin_url: str):
    response = requests.post(
        f"{BASE_URL}/api/v1/person/li-fact",
        headers={"X-Tiga-Auth": API_KEY, "Content-Type": "application/json"},
        json={"linkedin_url": linkedin_url},
    )
    if response.status_code == 200:
        return response.json()
    return None

with open(INPUT_FILE, newline="") as infile, open(OUTPUT_FILE, "w", newline="") as outfile:
    reader = csv.DictReader(infile)
    fieldnames = reader.fieldnames + ["headline", "current_title", "geo", "recent_role_change"]
    writer = csv.DictWriter(outfile, fieldnames=fieldnames)
    writer.writeheader()

    for i, row in enumerate(reader, 1):
        linkedin_url = row.get("linkedin_url", "")
        profile = get_linkedin_profile(linkedin_url) if linkedin_url else None

        row["headline"] = profile.get("headline", "") if profile else ""
        row["current_title"] = profile.get("current_title", "") if profile else ""
        row["geo"] = profile.get("geo", "") if profile else ""
        row["recent_role_change"] = profile.get("recent_role_change", "") if profile else ""

        writer.writerow(row)
        if i % 25 == 0:
            print(f"[{i}] records processed")

print(f"Done — results saved to {OUTPUT_FILE}")
```

4. **Complete** — give a simple summary, then ask the user if they want to open the file; if yes, call the `open` command.

## Notes

- Output format matches input format (CSV in → CSV out, JSON in → JSON out)
- Original columns are always preserved — LinkedIn fields are appended
- For large files (500+ rows), warn the user about API costs before running
- `TIGA_API_KEY` must come from the environment — never hardcode it
- `POST /api/v1/person/li-fact` (lookup by LinkedIn URL) is documented only here — the per-person `GET /api/v1/person/:id/li-fact` in `docs/api-reference.md` is a different route
