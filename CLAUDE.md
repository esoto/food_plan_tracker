# Food Plan Tracker — Claude Instructions

## Documentation

Project documentation lives in the Obsidian vault:
- **Path**: `Personal Brand/Food Plan Tracker/`
- **Vault**: `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Esteban's brain/`

All design documents, architecture decisions, and planning notes should be stored there and linked from this repo as needed.

## Development

- Follow the existing Rails conventions in this codebase.
- Keep test coverage high — controller and request specs are required for new endpoints.
- Use `Current.user` (via `ActiveSupport::CurrentAttributes`) for per-request user context.
- Food data (`foods` table) is global/shared across all users.
- All other data is user-scoped via `Tenantable` concern.
