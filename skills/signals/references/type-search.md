# Signal Type: `search`

Runs a Google search, scrapes results, and evaluates page content against a prompt using the LLM.

**Scope:** Account or person (set `is_account_insight` accordingly)

---

## Example

```json
{
  "label": "Digital Transformation News",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "search",
    "is_account_insight": true,
    "search_config": {
      "search_text": "{{.AccountName}} digital transformation OR IT modernization",
      "num_results": 5,
      "result_eval_prompt": "Does this result look relevant to {{.AccountName}}'s digital transformation initiatives?",
      "page_eval_prompt": "Summarize any mentions of digital transformation or IT modernization at {{.AccountName}}.",
      "should_render_javascript": false
    },
    "word_limit": 60
  }
}
```

---

## Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `is_account_insight` | boolean | Yes | `true` for account, `false` for person |
| `search_config.search_text` | string | Yes | Google search query — supports `{{.MergeField}}` variables |
| `search_config.result_eval_prompt` | string | Yes | LLM prompt to evaluate each search result snippet |
| `search_config.page_eval_prompt` | string | Yes | LLM prompt to evaluate scraped page content |
| `search_config.num_results` | integer | No | Number of search results to fetch |
| `search_config.search_type` | string | No | Search type selector |
| `search_config.should_render_javascript` | boolean | No | Enable JavaScript rendering when scraping pages |
| `word_limit` | integer | No | Max words in output |

> Merge field dependencies are extracted from the combined `search_text` + `result_eval_prompt` + `page_eval_prompt` strings.
