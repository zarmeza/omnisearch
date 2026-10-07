# Omnisearch

A mountable search engine for Rails apps, with pluggable providers.

Mount it in a Rails app and get a `/search` endpoint backed by Google, Bing, or
anything else you register. Built for the case where more than one app needs
search and the provider parsing should not be written twice.

```ruby
# Gemfile
gem "omnisearch"
```

```ruby
# config/initializers/omnisearch.rb
Omnisearch.configure do |config|
  config.providers = {
    google: { engine_id: ENV["GOOGLE_ENGINE_ID"], api_key: ENV["GOOGLE_API_KEY"] }
  }
end
```

```ruby
# config/routes.rb
mount Omnisearch::Engine => "/search"
```

```
GET /search/search?engine=google&text=ruby
```

```json
{
  "query": "ruby",
  "status": "ok",
  "status_by_provider": [
    { "provider": "google", "status": "ok", "error_messages": [] }
  ],
  "results": [
    { "title": "Ruby", "link": "https://www.ruby-lang.org/" }
  ]
}
```

## Design decisions

These are the four choices that shape everything else. Each was a judgement
call rather than a default, so they are worth stating outright.

### The host configures the cache, not the engine

`Omnisearch::Cache` is a thin adapter over `Rails.cache`. The engine never
calls `config.cache_store` and never assumes a database exists, so the same gem
works whether the host is on Solid Cache, Redis, memcached, or an in-memory
store.

The alternative — the engine owning its cache — is nicer to demo and worse to
adopt: it would impose a `cache` database on every host app, which is exactly
the kind of assumption that makes an engine annoying to depend on.

What the adapter *does* add is tolerance. `Rails.cache` raises when its store is
unavailable, and a cache that can take the API down is worse than no cache: an
uncached search costs one upstream HTTP request, a raised exception costs the
caller a 500. Every operation rescues and returns nil.

### Providers are registered by class

`Omnisearch::Registry` maps a declared name to a provider class. Registration is
idempotent by name, so a host can override a built-in by registering its own
subclass under the same name — no engine change required.

```ruby
class MyProvider < Omnisearch::Provider
  name :my_provider

  def self.request_url(query, config) = "https://example.test/?q=#{query}"
  def self.parse_response(body) = JSON.parse(body)
  def self.map_results(data) = [{ title: data["t"], link: data["u"] }]
end

Omnisearch.register(MyProvider)
```

A provider implements four methods and gets caching, aggregation, HTTP, and
error handling for free.

### A failing provider never fails the request

Each provider reports its own status and its own `error_messages`. One bad API
key cannot take down a search another engine could answer:

```json
{
  "status": "ok",
  "status_by_provider": [
    { "provider": "google", "status": "error",  "error_messages": ["HTTP 403"] },
    { "provider": "bing",   "status": "ok",    "error_messages": [] }
  ],
  "results": [ /* bing's results */ ]
}
```

`error_messages` is always an array, never null — including when a provider
succeeded. A field that is sometimes-null and sometimes-not is one every client
ends up special-casing.

This is also why `Omnisearch::Provider.available?` exists. Google without
credentials reports itself `:unavailable` rather than raising, so a
half-configured install still serves Bing.

### `engine: "both"` means every *registered* provider

Not a hardcoded list of two. Register a third provider and `both` picks it up.

## Response shape

| Key | Type | Notes |
|---|---|---|
| `query` | string | Echoes the text searched for |
| `status` | `:ok` / `:service_unavailable` | `ok` if *any* provider succeeded |
| `status_by_provider` | array | One entry per provider: `provider`, `status`, `error_messages` |
| `results` | array | `{ title, link }`, deduplicated by link across providers |

Invalid parameters return `422` with `{"errors": {"engine": "...", "text": "..."}}`.

## Providers

| Provider | Name | Needs |
|---|---|---|
| `Omnisearch::GoogleProvider` | `google` | `engine_id` and `api_key` |
| `Omnisearch::BingProvider` | `bing` | nothing — scrapes the HTML results page |

Bing needs no API key, which makes it the one engine that works the moment you
install the gem.

## Migrating from omnisearch-rails

This gem grew out of [`zarmeza/omnisearch-rails`](https://github.com/zarmeza/omnisearch-rails),
a standalone Rails API application. That repository is archived. The request and
response contract carried over unchanged:

```
GET /search?engine=google|bing|both&text=...
```

What differs is the packaging. The old app was a server you ran; this is a gem you
mount into a server you already have.

| | omnisearch-rails | omnisearch |
|---|---|---|
| Shape | Standalone Rails API app | Mountable engine |
| Install | `bundle install`, run it | `gem "omnisearch"`, `mount Omnisearch::Engine => "/search"` |
| Cache | Own Solid Cache database | Whatever the host already uses for `Rails.cache` |
| Providers | Google, Bing | Google, Bing, plus anything you register |
| Endpoint | `/search` | wherever you mount it |

The cache is the change most likely to surprise. The old app owned a
`db/cache_development.sqlite3` and needed `bin/prepare-cache`. The engine does
not: it reads `Rails.cache` and never calls `config.cache_store`, so there is
nothing to prepare and no second database to keep alive. The graceful-degradation
behaviour carried over — a cache outage still costs you performance, never
availability.

## Using it without HTTP

The engine is a plain Ruby object graph; the Rails parts are additive.

```ruby
Omnisearch.search(engine: "bing", text: "ruby")
# => { query: "ruby", status: :ok, status_by_provider: [...], results: [...] }
```

## Development

```console
$ bundle install
$ bundle exec rake       # tests + coverage
$ bundle exec rubocop
```

Ruby 3.3+, Rails 7.2+. 43 tests, 96% line coverage.

Tests never touch the network — WebMock is enabled with `disable_net_connect!`,
so a test that forgets to stub an HTTP call fails loudly rather than reaching
Google. Provider failures are asserted with fixtures rather than by poking a
live endpoint.

### Proving it is actually mountable

An engine that works in isolation and breaks when mounted is not an engine, so
the repository carries a host app that exists only to test that claim:

```console
$ cd dummy                   # a minimal Rails app with the gem mounted
$ bundle install
$ bundle exec rails test      # 11 integration tests through the full stack
```

Those tests go through the host's real routing and middleware, so a mistake in
`isolate_namespace`, the mount point, or the engine's own routes fails there and
nowhere else.

## Licence

MIT. See [LICENSE.txt](LICENSE.txt).
