# Bruno API Collection

This directory contains the Bruno collections and environments used to explore, document,
and test the project’s REST APIs.
Bruno is a fast, Git-friendly API client designed for teams that prefer version-controlled,
text-based API collections.

```text
bruno/
├── environments/
│   ├── env.bru.template    # Safe template, committed
│   └── local.bru           # Local values and tokens, ignored
└── config.json
```

## Getting Started

1. Install Bruno

```bash
   brew install --cask bruno
```

2. Create your environment file

Copy the template:

```bash
cp environments/env.bru.template environments/local.bru
```

Edit local.bru and fill in values such as:

```bash
baseURL: http://localhost:4551
userURL: http://localhost:4555
BEARER_TOKEN: <your-token-here>
```

⚠️ Never commit local.bru, .env files, or files containing tokens.

## Running Requests

Each .bru file represents a request.

You can:

- Run individual requests
- Run an entire folder as a suite
- Pass environment variables using {{VAR_NAME}} syntax

For authenticated local requests, run **Auth Token** first. It saves
`BEARER_TOKEN` in the selected environment. Reference-data requests are under
**Maintenance → Reference data**. Open a request's **Params** tab in Bruno to
customise its inputs for your target environment:

| Request | Parameter type | Parameter | Example value |
| --- | --- | --- | --- |
| Get maintenance applications | Query | `application_group` | `Create Casefile` |
| Get major creditors | Query | `business_unit_id` | `44` |
| Get result | Path | `resultId` | `MAT` |

These non-secret examples are saved with each request. Use **Get results** to
find an available `resultId`. Keep shared service URLs and authentication in
the environment; request-specific inputs do not need environment variables.

The **Ping** and **Auth check** requests require
`TESTING_SUPPORT_ENDPOINTS_ENABLED=true`. **Auth check** also requires a token.

Example:

```text
GET {{baseURL}}/health
Authorization: Bearer {{BEARER_TOKEN}}
```

## Git & Security Guidelines

✔ Commit:

- collections/
- config.json
- env.bru.template

❌ Do not commit:

- Any *.env file with real values
- Sensitive tokens in request headers

## Tips for Contributors

- Keep requests small and focused.
- Group related requests into folders (users/, auth/, orders/, etc.).
- Update collections when API endpoints change.
- Include sample payloads (JSON) in the request body to help others test faster.
