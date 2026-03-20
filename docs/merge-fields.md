# Merge Fields for Signal Prompts

Use `{{.FieldName}}` syntax in signal prompts. These are automatically replaced with the record's actual values at computation time.

## Person Fields

| Field | Description |
|-------|-------------|
| `{{.FirstName}}` | Person first name |
| `{{.LastName}}` | Person last name |
| `{{.Title}}` | Person job title |
| `{{.EmailAddress}}` | Person email |
| `{{.LinkedInUrl}}` | Person LinkedIn URL |
| `{{.Phone}}` | Person phone |
| `{{.City}}` | Person city |
| `{{.State}}` | Person state |
| `{{.Country}}` | Person country |
| `{{.IntentData}}` | Person intent data |
| `{{.LastRepliedAt}}` | Last reply date |

## Account Fields

| Field | Description |
|-------|-------------|
| `{{.AccountName}}` | Company name |
| `{{.AccountIndustry}}` | Company industry |
| `{{.AccountWebsite}}` | Company website |
| `{{.AccountLinkedInUrl}}` | Company LinkedIn URL |
| `{{.AccountCity}}` | Company city |
| `{{.AccountCountry}}` | Company country |
| `{{.AccountIntentData}}` | Account intent data |

## LinkedIn Profile Fields

| Field | Description |
|-------|-------------|
| `{{.PersonLi_Summary}}` | LinkedIn summary/about |
| `{{.PersonLi_Headline}}` | LinkedIn headline |
| `{{.PersonLi_Experience}}` | LinkedIn experience |
| `{{.PersonLi_Skills}}` | LinkedIn skills |
| `{{.PersonLi_RecentRoleChange}}` | Recent role change indicator |

## LinkedIn Company Fields

| Field | Description |
|-------|-------------|
| `{{.CompanyLi_Name}}` | Company LinkedIn name |
| `{{.CompanyLi_Website}}` | Company LinkedIn website |
| `{{.CompanyLi_CompanySize}}` | Company size from LinkedIn |
| `{{.CompanyLi_RecentFunding}}` | Recent funding from LinkedIn |

## User Fields

| Field | Description |
|-------|-------------|
| `{{.UserName}}` | Current user name |
| `{{.UserRole}}` | Current user role |

## Other Fields

| Field | Description |
|-------|-------------|
| `{{.ShortPitch}}` | Short pitch text |
| `{{.CurrentDate}}` | Current date |
| `{{.Last7Days}}` | Date 7 days ago |
| `{{.Last30Days}}` | Date 30 days ago |
| `{{.Last90Days}}` | Date 90 days ago |

## Custom Merge Fields

Discover available custom fields via:
- Account fields: `GET /api/v1/account/columns?mode=merge_fields`
- Person fields: `GET /api/v1/person/columns?mode=merge_fields`
