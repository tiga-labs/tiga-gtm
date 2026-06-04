# Merge Fields

## Two syntaxes — use the right one

| Context | Syntax to use |
|---------|--------------|
| AI prompt templates (p13n prompts, signal prompts, AI email prompts) | Plain `{{.FieldName}}` |
| `email_body` and `linkedin_message` (HTML fields in TipTap) | `<span class="tiga-merge">` HTML element (see below) |

---

## HTML merge field format (for email_body and linkedin_message)

Email bodies and LinkedIn messages are stored as TipTap HTML. Merge fields inside them **must** use this span format or they will appear as raw literal text in the editor instead of interactive chips:

```html
<span class="tiga-merge" data-custom-column-id="null" data-computed-config-type="null" data-value="{{.FieldName}}" data-entity="EntityType" data-alt-text="">Display Label</span>
```

Key attributes:
- `data-value` — the Go template variable, e.g. `{{.FirstName}}`
- `data-entity` — controls the icon shown in the editor (see entity types below)
- `data-alt-text` — fallback text if the field is empty (use `""` for none)
- `data-custom-column-id` — use `"null"` for standard fields; use the column UUID for custom/p13n fields
- `data-computed-config-type` — use `"null"` for standard fields; use the computed config type for p13n fields
- Inner text content — human-readable label shown in the chip (e.g. `First Name`)

### Entity types

| Entity value | Used for |
|---|---|
| `Person` | Person fields (FirstName, LastName, Title, EmailAddress, etc.) |
| `Account` | Account fields (AccountName, AccountIndustry, AccountWebsite, etc.) |
| `LiPersonFact` | LinkedIn person profile fields (PersonLi_*) |
| `LiCompanyFact` | LinkedIn company fields (CompanyLi_*) |
| `User` | User fields (UserName, UserRole) |
| `CurrentDate` | CurrentDate |
| `SearchDays` | Last7Days, Last30Days, Last90Days, etc. |
| `AiSection` | P13n / AI-generated personalizations |

### Full example email body

```html
<p>Hi <span class="tiga-merge" data-custom-column-id="null" data-computed-config-type="null" data-value="{{.FirstName}}" data-entity="Person" data-alt-text="">First Name</span>,</p>
<p><span class="tiga-merge" data-custom-column-id="a1b2c3d4-..." data-computed-config-type="gpt" data-value="{{.personalized_opening_a1b2c3}}" data-entity="AiSection" data-alt-text="">Personalized Opening</span></p>
<p>Would love to connect and share how we help teams like <span class="tiga-merge" data-custom-column-id="null" data-computed-config-type="null" data-value="{{.AccountName}}" data-entity="Account" data-alt-text="">Account Name</span>.</p>
<p>Best,<br><span class="tiga-merge" data-custom-column-id="null" data-computed-config-type="null" data-value="{{.UserName}}" data-entity="User" data-alt-text="">User's Name</span></p>
```

### P13n merge fields

When wiring a p13n into a step, use the `key` from the p13n response (e.g. `personalized_opening_a1b2c3`) and the `id` / `computed_config.type` from the p13n response:

```html
<span class="tiga-merge" data-custom-column-id="<p13n-id>" data-computed-config-type="<computed_config.type>" data-value="{{.personalized_opening_a1b2c3}}" data-entity="AiSection" data-alt-text=""><p13n-label></span>
```

---

## Plain-text merge fields (for prompts only)

Use `{{.FieldName}}` directly in string fields that are AI prompt templates. **Do not** use the span format in prompts — prompts are plain text, not HTML.

### Person Fields

| Field | Display label |
|-------|-------------|
| `{{.FirstName}}` | First Name |
| `{{.LastName}}` | Last Name |
| `{{.Title}}` | Title |
| `{{.EmailAddress}}` | Email Address |
| `{{.LinkedInUrl}}` | LinkedIn URL |
| `{{.Phone}}` | Phone |
| `{{.MobilePhone}}` | Mobile Phone |
| `{{.City}}` | City |
| `{{.State}}` | State |
| `{{.Country}}` | Country |
| `{{.IntentData}}` | Intent Data |
| `{{.LastRepliedAt}}` | Last Reply Date |

### Account Fields

| Field | Display label |
|-------|-------------|
| `{{.AccountName}}` | Account Name |
| `{{.AccountIndustry}}` | Industry |
| `{{.AccountWebsite}}` | Website |
| `{{.AccountDomain}}` | Domain |
| `{{.AccountLinkedInUrl}}` | LinkedIn Url |
| `{{.AccountCity}}` | City |
| `{{.AccountRegion}}` | Region |
| `{{.AccountCountry}}` | Country |
| `{{.AccountIntentData}}` | Account Intent Data |

### LinkedIn Profile Fields

| Field | Display label |
|-------|-------------|
| `{{.PersonLi_Summary}}` | Profile Summary |
| `{{.PersonLi_Headline}}` | Headline |
| `{{.PersonLi_About}}` | About |
| `{{.PersonLi_Experience}}` | Experience |
| `{{.PersonLi_Skills}}` | Skills |
| `{{.PersonLi_Posts}}` | Posts |
| `{{.PersonLi_RecentPosts}}` | Recent Posts |
| `{{.PersonLi_Education}}` | Education |
| `{{.PersonLi_RecentRoleChange}}` | RecentRoleChange |

### LinkedIn Company Fields

| Field | Display label |
|-------|-------------|
| `{{.CompanyLi_Name}}` | Name |
| `{{.CompanyLi_Description}}` | Description |
| `{{.CompanyLi_Website}}` | Website |
| `{{.CompanyLi_Tagline}}` | Tagline |
| `{{.CompanyLi_CompanySize}}` | Company Size |
| `{{.CompanyLi_LatestFunding}}` | Latest Funding |
| `{{.CompanyLi_RecentPosts}}` | Recent Posts |

### User Fields

| Field | Display label |
|-------|-------------|
| `{{.UserName}}` | User's Name |
| `{{.UserRole}}` | User's Role |

### Other Fields

| Field | Display label |
|-------|-------------|
| `{{.ShortPitch}}` | Short Pitch |
| `{{.CurrentDate}}` | Current Date |
| `{{.Last7Days}}` | Last 7 Days |
| `{{.Last30Days}}` | Last 30 Days |
| `{{.Last90Days}}` | Last 90 Days |

## Custom Merge Fields

Discover available custom fields via:
- Account fields: `GET /api/v1/account/columns?mode=merge_fields`
- Person fields: `GET /api/v1/person/columns?mode=merge_fields`
