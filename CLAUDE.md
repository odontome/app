# Odontome

Dental practice management app (Ruby on Rails). Users are non-tech-savvy dental professionals — all UI copy should be warm, simple, and jargon-free.

## Stack
- Ruby on Rails, Minitest (test/), ERB views
- Three locales: en, es, pt — always add translations to all three

## Conventions
- Never use `default:` on `I18n.t` calls
- Commit messages: `feat/fix/refactor(scope): description`
- Tests: `bin/rails test` (full suite), `bin/rails test test/functional/path` (targeted)

## MCP Agent
- Code: `app/controllers/api/agent/mcp_controller.rb` + `app/controllers/api/agent/mcp/`
- Never expose PII (email, phone, address, date of birth, allergies, insurance) through agent API responses. Only return names and internal IDs needed for scheduling.

## Key paths
- MCP agent: `app/controllers/api/agent/mcp_controller.rb` + `app/controllers/api/agent/mcp/`
- Locales: `config/locales/{en,es,pt}.yml`
