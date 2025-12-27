## 0011-Local-Transaction-Enrichment-PRD.md

#### Overview
This PRD defines a local transaction enrichment endpoint that provides a privacy-focused alternative to Plaid's enrichment features. Plaid's current enrichment capabilities include transaction categorization (e.g., assigning categories like "Groceries" or "Travel" based on merchant data), merchant name cleaning, location data appending, and adding metadata like logos or payment channels. These are typically cloud-based and involve sending sensitive data to Plaid's servers, which conflicts with our vision of Private Financial Data Sync for high-net-worth (HNW) families. Our local alternative leverages Ollama-powered AI models running entirely on the user's device to perform similar enrichments (e.g., categorizing transactions, cleaning merchant names) without any data leaving the local environment. This endpoint focuses solely on the `/transactions/enrich` API, ensuring atomicity while enhancing data usability for family financial syncing in a secure, offline-capable manner.

#### Log Requirements
(Read junie-log-requirement.md)  
All operations must adhere to the logging standards in `knowledge_base/static_docs/junie-log-requirement.md`. Specifically:  
- Log enrichment requests with anonymized transaction IDs only (no PII).  
- Use INFO level for successful enrichments and ERROR for failures (e.g., model inference errors).  
- Store logs locally in `/logs/enrichment/` with rotation every 7 days.  
- Ensure logs capture input/output shapes without sensitive data, e.g., "Enriched 5 transactions with categories assigned."

#### Requirements
**Functional Requirements:**  
- The endpoint `/transactions/enrich` accepts a POST request with a JSON payload containing an array of raw transaction objects (e.g., {id, amount, description, date}).  
- Use local Ollama models (e.g., fine-tuned Llama variant) to perform enrichment tasks: categorize transactions (e.g., map "Starbucks" to "Dining"), clean merchant names (e.g., normalize "AMZN Mktp US" to "Amazon"), and append basic metadata like inferred payment type (e.g., "credit card" based on patterns).  
- Return enriched transactions in JSON format with added fields: category, cleaned_merchant, inferred_type.  
- Support batch processing for up to 100 transactions per request to maintain efficiency for HNW family data syncs.  

**Non-Functional Requirements:**  
- All processing must occur locally using Python scripts integrated with Ollama; no external API calls.  
- Response time under 5 seconds for batches of 50 transactions on standard hardware (e.g., M1 Mac or equivalent).  
- Ensure compatibility with Rails MVC: Controller handles requests, Model manages data schema, View returns JSON.  
- Privacy: Encrypt temporary in-memory data during processing and delete after response.

#### Architectural Context
This feature integrates into the Rails MVC structure:  
- **Controller**: `app/controllers/transactions_controller.rb` with an `enrich` action to handle POST requests and invoke the service layer.  
- **Model**: Extend `Transaction` model in `app/models/transaction.rb` with enrichment methods, referencing schema in `db/schema.rb` (add columns: category:string, cleaned_merchant:string, inferred_type:string if not present).  
- **Service Layer**: A Python script in `lib/python/enrichment.py` uses Ollama API (local instance) for AI inference; called via Ruby's `system` or subprocess for local execution.  
- **Local AI**: Leverage Ollama for running lightweight models (e.g., a custom fine-tuned model stored in `models/enrichment/`) to avoid any cloud dependency.  
- Directory Structure: Place Python utilities in `lib/python/`, ensuring seamless integration with Rails app.

#### Acceptance Criteria
- Endpoint returns 200 OK with enriched JSON for valid batch inputs, including at least category and cleaned_merchant fields for each transaction.  
- Enrichment categorizes common merchants accurately (e.g., "Walmart" -> "Groceries") based on local model training data.  
- No data is transmitted externally; verified by network monitoring during tests.  
- Handles edge cases like empty descriptions by assigning a default "Uncategorized" label.  
- Batch processing supports up to 100 items without performance degradation (under 5s response).  
- Error handling: Returns 400 Bad Request with message for invalid payloads (e.g., missing required fields).  
- Logs are generated per junie-log-requirement.md, accessible in `/logs/enrichment/`.  
- Integration with existing Transaction model schema, ensuring no data loss on enrichment.

#### Test Cases
**Unit Tests:**  
- Test `TransactionsController#enrich` for parsing JSON input and calling enrichment service.  
- Mock Ollama inference in Python script to verify category assignment logic (e.g., assert "McDonalds" -> "Dining").  

**Integration Tests:**  
- End-to-end POST to `/transactions/enrich` with sample transactions; assert enriched output matches expected JSON structure.  
- Verify no external network calls using tools like Wireshark during enrichment.  

**System Tests:**  
- Simulate HNW family data sync: Enrich 50 transactions and confirm response time <5s on local setup.  
- Load test with 100 transactions to ensure batch handling without crashes.

#### Workflow
1. `git checkout -b feature/0011-local-transaction-enrichment`  
2. Implement changes in Rails files and Python scripts as per Architectural Context.  
3. Run tests: `rails test` and manual Python unit tests via `python lib/python/test_enrichment.py`.  
4. Commit: `git commit -m "Implement local transaction enrichment endpoint [0011]"`  
5. Push and PR: `git push origin feature/0011-local-transaction-enrichment` followed by creating a Pull Request on GitHub targeting main.  
6. After merge, update backlog with new entry if approved.