## Quick orientation

This is a Rails 8 application for a restaurant reservation system. Key domains:
- Reservations (business rules live in `app/models/reservation.rb`)
- Tables (`app/models/table.rb`) and availability checks
- Time slots (`app/models/time_slot.rb`) which drive capacity rules
- Users with `has_secure_password` for authentication (`app/models/user.rb`)

There is an admin area (namespace: `admin`) served by `app/controllers/admin/*` and views under `app/views/admin/*`.

## Architecture highlights (what an AI should know first)
- Rails 8 app using importmap for JavaScript (`config/importmap.rb`) and Hotwire (Turbo & Stimulus).
- Server entry points: `bin/dev` starts the Rails server; `bin/setup` installs deps and runs `bin/rails db:prepare`.
- PostgreSQL is the database (see `Gemfile` for `pg`) and DB is prepared via standard Rails tasks.
- Model-centered business logic: reservation availability, table assignment, and validation rules live in model callbacks and custom validators rather than controllers. See `Reservation#assign_available_table`, `Table#available_for_slot?`, and `TimeSlot#available?`.

## Authentication & authorization
- Session-based auth. `session[:user_id]` is used to identify `current_user` (`ApplicationController#current_user`).
- Admin guard methods: `require_admin` and `admin_user?` live in `ApplicationController` — respect these when editing controllers or views.

## Project-specific conventions and patterns
- Prefer placing business rules in models (e.g., default status set via `after_initialize`, table assignment in `before_validation`).
- Status default: Reservations default to `'confirmed'` via `set_default_status` — changing that impacts many flows.
- Capacity logic: `Table.by_capacity` and `TimeSlot.available_tables_for_date` are the places to inspect when adjusting availability or capacity rules.
- JavaScript uses importmap + Stimulus controllers under `app/javascript/controllers` (pinned in `config/importmap.rb`).

## Common developer workflows (commands)
- Local setup (installs deps, prepares DB, and starts server):
  - `bin/setup` (this runs `bundle install` and `bin/rails db:prepare` and then `bin/dev` by default)
- Start server manually: `bin/dev` (executes `bin/rails server`)
- Run tests: `bin/rails test` (Minitest + system tests using Capybara are present under `test/`)
- Run linters/security scans (development group):
  - `bundle exec brakeman` (security scan)
  - `bundle exec rubocop` (if configured locally)
- Docker: a `Dockerfile` and `docker-entrypoint` are present for containerized runs.

## Files to consult when making changes
- Domain logic: `app/models/reservation.rb`, `app/models/table.rb`, `app/models/time_slot.rb`
- Controllers: `app/controllers/reservations_controller.rb`, and admin controllers in `app/controllers/admin/`.
- Routes: `config/routes.rb` (note `admin` namespace and `reservations#availability` collection route).
- JS: `app/javascript/controllers/*` and `config/importmap.rb` for frontend behavior.
- Startup scripts: `bin/setup`, `bin/dev`.
- Deployment helpers: `Gemfile` (kamal, thruster), `Dockerfile` and `bin/docker-entrypoint`.

## Safety notes / gotchas
- Many business rules are enforced in model validations (e.g., reservations must be >= 2 hours in advance). When adjusting UI or controllers, keep validation messages and timing rules in sync.
- Table assignment is optimistic: `Reservation#assign_available_table` selects the first available table by capacity — concurrency and race conditions may require additional handling for heavy load.
- `allow_browser versions: :modern` is used in `ApplicationController` — some browser features (webp, importmap) are assumed available.

## Examples for quick lookups
- To understand table assignment: open `app/models/reservation.rb` -> `assign_available_table`.
- To see admin-only endpoints: open `app/controllers/admin/*` and `config/routes.rb` for the admin namespace.

## How to ask for changes from an AI assistant
- When proposing a change, reference the specific file(s) and lines (e.g., "change assignment logic in `app/models/reservation.rb#assign_available_table`").
- For UI changes that affect validation rules, include the model change plus the corresponding view/controller adjustments and a small test in `test/models` or `test/system`.

If anything here is unclear or you'd like more detail (examples of tests, preferred rubocop rules, or deployment steps with Kamal/Docker), tell me which area to expand. 
