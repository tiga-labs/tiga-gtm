# Go App Template

This is the reference implementation for CRM bulk ops tools. Adapt the types, queries, and processing logic to match the specific operation.

## Project setup

```bash
go mod init <project-name>
go get github.com/joho/godotenv
```

## .env file

```
TIGA_API_KEY=<key>
```

## main.go structure

The file follows this order:
1. Imports + embedded HTML
2. Configuration constants
3. CSV logger (init, append, read processed IDs)
4. Logged HTTP helper (`apiDo`)
5. Types (status enum, change entry, app state)
6. Tiga/CRM API functions
7. Processing logic (worker pool)
8. HTTP handlers (status, scan, apply, undo, stop, reset)
9. Main function

## Core patterns

### Logged HTTP helper

Every external API call goes through this — provides consistent logging for debugging.

```go
func apiDo(method, url string, body io.Reader, headers map[string]string) ([]byte, int, error) {
	log.Printf("[API] %s %s", method, url)
	req, err := http.NewRequest(method, url, body)
	if err != nil {
		return nil, 0, err
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Printf("[API] %s %s -> ERROR: %v", method, url, err)
		return nil, 0, err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	log.Printf("[API] %s %s -> %d (%d bytes)", method, url, resp.StatusCode, len(data))
	return data, resp.StatusCode, nil
}
```

### CSV logger

Tracks every record processed. Enables resume by reading back processed IDs.

```go
const csvLogFile = "crm_ops_log.csv"
var csvMu sync.Mutex

func initCSVLog() {
	csvMu.Lock()
	defer csvMu.Unlock()
	if _, err := os.Stat(csvLogFile); err == nil {
		return
	}
	f, err := os.Create(csvLogFile)
	if err != nil {
		log.Printf("Failed to create CSV log: %v", err)
		return
	}
	defer f.Close()
	w := csv.NewWriter(f)
	w.Write([]string{"timestamp", "operation", "crm_id", "old_value", "new_value", "error"})
	w.Flush()
}

func logCSV(operation, crmID, oldVal, newVal, errMsg string) {
	csvMu.Lock()
	defer csvMu.Unlock()
	f, err := os.OpenFile(csvLogFile, os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil { return }
	defer f.Close()
	w := csv.NewWriter(f)
	w.Write([]string{time.Now().UTC().Format(time.RFC3339), operation, crmID, oldVal, newVal, errMsg})
	w.Flush()
}

func readProcessedIDs(operation string) map[string]bool {
	csvMu.Lock()
	defer csvMu.Unlock()
	ids := make(map[string]bool)
	f, err := os.Open(csvLogFile)
	if err != nil { return ids }
	defer f.Close()
	records, err := csv.NewReader(f).ReadAll()
	if err != nil { return ids }
	for _, row := range records[1:] {
		if len(row) >= 3 && row[1] == operation {
			ids[row[2]] = true
		}
	}
	return ids
}
```

### State machine

```go
type AppStatus string

const (
	StatusIdle     AppStatus = "idle"
	StatusScanning AppStatus = "scanning"
	StatusScanned  AppStatus = "scanned"
	StatusApplying AppStatus = "applying"
	StatusApplied  AppStatus = "applied"
	StatusUndoing  AppStatus = "undoing"
	StatusStopped  AppStatus = "stopped"
)

type AppState struct {
	mu          sync.Mutex
	cancel      context.CancelFunc
	Status      AppStatus     `json:"status"`
	Message     string        `json:"message"`
	TotalRecords int          `json:"total_records"`
	Processed   int           `json:"processed"`
	Changes     []ChangeEntry `json:"changes"`
	Applied     []ChangeEntry `json:"applied"`
	ScanError   string        `json:"scan_error,omitempty"`
	ApplyErrors []string      `json:"apply_errors,omitempty"`
	LastOp      string        `json:"last_op,omitempty"`
}

func (s *AppState) set(fn func()) {
	s.mu.Lock()
	defer s.mu.Unlock()
	fn()
}
```

### Start operation helper

Prevents concurrent operations and sets up cancellation context.

```go
func startOp(w http.ResponseWriter, status AppStatus, msg string) (context.Context, bool) {
	state.mu.Lock()
	defer state.mu.Unlock()
	if state.Status == StatusScanning || state.Status == StatusApplying || state.Status == StatusUndoing {
		http.Error(w, "operation already in progress", http.StatusConflict)
		return nil, false
	}
	ctx, cancel := context.WithCancel(context.Background())
	state.cancel = cancel
	state.Status = status
	state.Message = msg
	state.ScanError = ""
	state.Processed = 0
	return ctx, true
}

func cancelled(ctx context.Context) bool {
	select {
	case <-ctx.Done(): return true
	default: return false
	}
}
```

### Worker pool for concurrent processing

Use for scan operations where each record requires an independent API call (e.g., name cleaning, enrichment submission).

```go
const scanWorkers = 5

// In the scan goroutine:
type result struct {
	Record  CRMRecord
	Output  string
	Err     error
}

jobs := make(chan CRMRecord, scanWorkers)
results := make(chan result, scanWorkers)

var wg sync.WaitGroup
for w := 0; w < scanWorkers; w++ {
	wg.Add(1)
	go func() {
		defer wg.Done()
		for rec := range jobs {
			out, err := processRecord(rec)
			results <- result{Record: rec, Output: out, Err: err}
		}
	}()
}

go func() { wg.Wait(); close(results) }()

go func() {
	defer close(jobs)
	for _, rec := range records {
		if cancelled(ctx) { return }
		jobs <- rec
	}
}()

// Collect from results channel...
```

### Salesforce Composite API for batch writes

```go
const sfBatchSize = 25 // SF Composite limit is 25

type compositeSubrequest struct {
	Method      string            `json:"method"`
	URL         string            `json:"url"`
	ReferenceID string            `json:"referenceId"`
	Body        map[string]string `json:"body,omitempty"`
}

type compositeRequest struct {
	AllOrNone        bool                  `json:"allOrNone"`
	CompositeRequest []compositeSubrequest `json:"compositeRequest"`
}

type compositeSubresponse struct {
	ReferenceID    string          `json:"referenceId"`
	HTTPStatusCode int             `json:"httpStatusCode"`
	Body           json.RawMessage `json:"body"`
}

type compositeResponse struct {
	CompositeResponse []compositeSubresponse `json:"compositeResponse"`
}

// Build subrequests, POST to {instance_url}/services/data/v59.0/composite
```

### HubSpot batch update pattern

```go
const hsBatchSize = 100

type hsBatchInput struct {
	ID         string            `json:"id"`
	Properties map[string]string `json:"properties"`
}

type hsBatchRequest struct {
	Inputs []hsBatchInput `json:"inputs"`
}

// POST to https://api.hubapi.com/crm/v3/objects/{objectType}/batch/update
```

### Handler pattern

Each handler: validate state → copy data → start goroutine → return immediately.

```go
func handleScan(w http.ResponseWriter, r *http.Request) {
	resume := r.URL.Query().Get("resume") == "true"

	ctx, ok := startOp(w, StatusScanning, "Starting...")
	if !ok { return }

	go func() {
		// 1. Get CRM token
		// 2. Query CRM records
		// 3. If resume, load skipIDs from CSV
		// 4. Process with worker pool
		// 5. Update state on completion or cancellation
	}()

	jsonReply(w, map[string]string{"status": "scanning"})
}
```

### Route setup

```go
http.HandleFunc("/", serveIndex)
http.HandleFunc("/api/status", handleStatus)
http.HandleFunc("/api/scan", handleScan)
http.HandleFunc("/api/apply", handleApply)
http.HandleFunc("/api/undo", handleUndo)
http.HandleFunc("/api/stop", handleStop)
http.HandleFunc("/api/reset", handleReset)
```

## index.html template

Dark-themed SPA with these elements:
- Status bar: colored dot (idle=gray, working=yellow pulse, done=green, stopped=orange, error=red) + message
- Progress bar: shown during operations, percentage based on processed/total
- Buttons: Scan (green), Stop (yellow, shown when busy), Resume (blue, shown when stopped), Restart (gray, shown when stopped), Apply (gray), Undo (red)
- Stats: 3 cards showing total records, to change, applied
- Table: old value → arrow → new value for each change
- Error box: yellow/orange, shown when errors exist
- Polls `/api/status` every 1 second during operations, stops when idle/scanned/applied/stopped

Key JS functions:
```javascript
async function scan() { await fetch('/api/scan', {method:'POST'}); startPolling(); }
async function stop() { await fetch('/api/stop', {method:'POST'}); }
async function resume() { await fetch('/api/<lastOp>?resume=true', {method:'POST'}); startPolling(); }
async function restart() { await fetch('/api/reset', {method:'POST'}); await scan(); }
```

## launch.json for preview

```json
{
  "version": "0.0.1",
  "configurations": [
    {
      "name": "<project-name>",
      "runtimeExecutable": "go",
      "runtimeArgs": ["run", "."],
      "port": 8080
    }
  ]
}
```
