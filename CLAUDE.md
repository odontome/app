# Odontome

Dental practice management app (Ruby on Rails). Users are non-tech-savvy dental professionals — all UI copy should be warm, simple, and jargon-free.

## Stack
- Ruby on Rails, Minitest (test/), ERB views
- Three locales: en, es, pt — always add translations to all three

## Conventions
- Never use `default:` on `I18n.t` calls
- Commit messages: `feat/fix/refactor(scope): description`
- Tests: `bin/rails test` (full suite), `bin/rails test test/functional/path` (targeted)

## Key paths
- MCP agent: `app/controllers/api/agent/mcp_controller.rb` + `app/controllers/api/agent/mcp/`
- Locales: `config/locales/{en,es,pt}.yml`
