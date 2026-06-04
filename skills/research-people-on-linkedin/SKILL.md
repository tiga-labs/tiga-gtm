---
name: research-people-on-linkedin
description: Enrich a file of people with LinkedIn data via the Tiga API. Use this skill 
  when the user provides a CSV, Excel, or JSON file containing people records and wants 
  LinkedIn profile data appended to each row. Triggers on phrases like "enrich this list", 
  "add LinkedIn data to this file", "research these people", or any time a people file 
  is uploaded alongside a LinkedIn enrichment request.
---

# Research list of people

Enrich a file of people records with LinkedIn data using the Tiga API.

Supported input formats: `.csv`, `.tsv` and similar fiels

---

## Step 1 — Identify and inspect the file

Preview the first few rows to understand its shape:

**CSV / TSV:**
```python
import pandas as pd
df = pd.read_csv("./people.csv", nrows=5)
print(df.columns.tolist())
print(df.head())
```
```

---

## Step 2 — Confirm the linkedin_url column

Look at the column names from Step 1. The LinkedIn URL column is usually named:
`linkedin_url`, `linkedin`, `profile_url`, `li_url`

If it's ambiguous or missing, ask the user: *"Which column contains the LinkedIn URLs?"*

Do not proceed without a confirmed URL column.

valid linkedin url should look something like this: "www.linkedin.com/in/<profile_id>"

---

## Step 3 — Write and run the enrichment script

Write a script then execute it.
Please reduce logging to ensure conserve tokens.
Give a simple [25/250] 10.00% complete every 25 records process

```
import csv                                                                                                              
  import requests
                                                                                                                          
  API_KEY = "YOUR_API_KEY"
  INPUT_FILE = "people.csv"                                                                                               
  OUTPUT_FILE = "people_enriched.csv"                                                                                     
   
  def get_linkedin_profile(linkedin_url: str):                                                                            
      response = requests.post(
          "https://app.tigalabs.com/api/v1/person/li-fact",                                                               
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
                                                                                                                          
      for row in reader:                                                                                                  
          linkedin_url = row.get("linkedin_url", "")
          profile = get_linkedin_profile(linkedin_url) if linkedin_url else None
                                                                                                                          
          row["headline"] = profile.get("headline", "") if profile else ""
          row["current_title"] = profile.get("current_title", "") if profile else ""                                      
          row["geo"] = profile.get("geo", "") if profile else ""                                                          
          row["recent_role_change"] = profile.get("recent_role_change", "") if profile else ""
                                                                                                                          
          writer.writerow(row)                                                                                            
          
          print(f"{'✓' if profile else '✗'} {linkedin_url}")
                                                                                                                          
  print(f"\nDone — results saved to {OUTPUT_FILE}")
```

Run it

## Step 5 — Complete
Give a simple summary

ask the user if they want to open the file
if yes call the open command
---

## Notes

- Output format matches input format (CSV in → CSV out, JSON in → JSON out)
- Original columns are always preserved — LinkedIn fields are appended
- `li_raw_json` contains the full API response as a string for downstream use
- For large files (500+ rows), warn the user about API costs before running
- `TIGA_API_KEY` must be defined or an environment variable