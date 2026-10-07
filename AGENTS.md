# Omnisearch Agent Guide

Guidance for AI coding agents working in this repository.

## Before starting work

```console
$ carrot-handoff load
```

If a note exists, work is already in progress. Follow its `Next action` and do
not re-derive what `Decisions` already settled. `Tried and failed` exists because
two agents handed the same task will retry the same dead end — read it.

If there is no note, that means this is a fresh start.

## Before finishing

```console
$ carrot-handoff save "<one-line task>"
```

Then fill in, by hand, the sections only a human or agent can know:

- `Decisions` — choices made, including the options rejected and why.
- `Tried and failed` — what did not work, and why. **The valuable one.** Git
  has no record of dead ends; this is the only place they survive.
- `Next action` — the single next step, specific enough to start cold.
- `Open questions` — anything unverified or blocked.

`State` is machine-derived and regenerates on every save. Do not edit it.

Commit the note. That is what makes it survive a context reset, a session that
died, or a power cut.

## Save more often than that

The instructions above say "before finishing". For work that spans more than one
session, save after every real decision instead. A power cut takes whatever is
uncommitted with it, and an outage costs minutes of work rather than the thread
if the note is already written.

## Layout

```text
omnisearch.gemspec      gemspec; description is what RubyGems shows
lib/omnisearch.rb       entry point: module, errors, module-level config API
lib/omnisearch/
  version.rb            VERSION
  errors.rb             Misconfigured, ProviderNotRegistered
  registry.rb           name => provider class, idempotent by name
  provider.rb           base class; the four-method provider contract
  providers/
    google_provider.rb  Custom Search JSON API
    bing_provider.rb    HTML scraping, no API key
  query.rb              validation, per-provider status, dedup by link
  cache.rb              failure-tolerant adapter over Rails.cache
  configuration.rb      Omnisearch.configure
  engine.rb             the Rails::Engine subclass
  controllers/
    search_controller.rb
config/routes.rb        engine routes: GET /search, root
app/                    the controller
dummy/                  a minimal Rails app that exists only to be mounted into
test/                   43 unit tests
```

## Commands

```console
$ bundle install
$ bundle exec rake        # tests + coverage
$ bundle exec rubocop
$ cd dummy && bundle exec rails test    # 11 integration tests
```

## Conventions

**The engine never configures the host.** No `config.cache_store`, no migrations,
no assumptions about a database. `Rails.cache` is used as-is. This is what makes
the gem mountable into an app it knows nothing about.

**Cache operations must never raise.** A cache outage costs performance; an
exception costs the caller a 500. Every operation in `cache.rb` rescues and
returns nil.

**Provider failures never raise either.** They are reported per provider in
`status_by_provider`, so one bad API key cannot take down a search another
engine could answer. `Provider.available?` reports a missing-credentials Google
as `:unavailable` rather than raising, so a half-configured install still serves
Bing.

**Tests never touch the network.** WebMock with `disable_net_connect!` is
enabled suite-wide, so a test that forgets to stub fails loudly instead of
quietly reaching Google.

**`dummy/` is generated Rails output.** It is excluded from RuboCop on purpose.
Editing generated scaffolding to satisfy a linter is not worth the diff.

**`AllCops: Exclude` replaces RuboCop's defaults rather than merging.** The
four defaults (`node_modules`, `tmp`, `vendor`, `.git`) are restated in
`.rubocop.yml` deliberately. Removing `vendor/**/*` makes RuboCop read vendored
gems' own configs — see `Tried and failed` in `.carrot.md` for how that
presents.