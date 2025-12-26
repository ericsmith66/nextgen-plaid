# SmartProxy Sinatra Server

Standalone Sinatra proxy for Grok (xAI API) calls.

## Setup

1. Install dependencies:
   ```bash
   cd smart_proxy
   bundle install
   ```

2. Configure environment variables (in `.env` or system):
   - `GROK_API_KEY`: Your xAI API key.
   - `PROXY_AUTH_TOKEN`: Token required for authentication with this proxy.
   - `SMART_PROXY_PORT`: Port to run the server on (default: 4567).

## Usage

Start the server:
```bash
rackup -p 4567
```

### Endpoints

#### GET /health
Basic health check.
Returns: `{ "status": "ok" }`

#### POST /proxy/generate
Forwards a request to Grok API after anonymization.

**Headers:**
- `Authorization: Bearer <PROXY_AUTH_TOKEN>`
- `Content-Type: application/json`

**Body:**
Same as Grok Chat Completions API payload.

## Features

- **Anonymization**: Strips PII (Email, Phone, SSN, Credit Card) from outgoing requests.
- **Logging**: Structured JSON logging in `log/smart_proxy.log` with daily rotation.
- **Retries**: Automatically retries on 429 and 5xx errors from Grok API.
- **Function Calling**: Supports tool definitions and returns tool calls from Grok.

## Testing

Run tests:
```bash
bundle exec rspec
```
