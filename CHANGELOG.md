# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **`engine: "both"` is now `engine: "all"`.** The wildcard already meant every
  *registered* provider, so this is a rename rather than a behaviour change, but
  it breaks any caller still sending `both` — `both` is no longer accepted. This
  is the one deliberate incompatibility with `omnisearch-rails`, made because the
  old name was a leftover from when Google and Bing were the only two providers.
- A blank, missing, or malformed `engine` now reports `is required` or a message
  about the expected shape, instead of `"" is not a registered provider`.

### Added

- `engine` accepts a list of providers, so a query can run an explicit subset.
  Comma-separated (`engine=google,bing`) and Rails' array form
  (`engine[]=google&engine[]=bing`) both work over HTTP; the Ruby API takes an
  Array. Order is preserved and meaningful: the first provider in the list wins
  when two return the same link. A list is all-or-nothing — one unknown name
  returns `422` and searches nothing rather than silently dropping that provider.
- `engine=all` combined with a named provider is rejected as self-contradictory,
  with a message pointing at `engine=all` alone.

No published gem yet. Install from GitHub while this is true:

```ruby
gem "omnisearch", github: "zarmeza/omnisearch"
```

## [0.1.0] — 2026-10-06

Initial release.

### Added

- `Omnisearch::Engine`, a mountable Rails engine providing `GET /search`.
- `Omnisearch::Provider`, the base class for a search provider, and
  `Omnisearch::Registry` for registering them by name. Host apps can add
  providers without changing the engine, and replace the built-ins by
  re-registering the same name.
- `Omnisearch::GoogleProvider` (Custom Search JSON API) and
  `Omnisearch::BingProvider` (HTML results, no API key).
- `Omnisearch::Query`, which validates a request and aggregates provider
  results: deduplicated by link, with a per-provider status and an always-array
  `error_messages`.
- `Omnisearch::Cache`, a failure-tolerant adapter over `Rails.cache`. The engine
  does not configure a store — the host app's `config.cache_store` is used as-is,
  and an unavailable cache degrades to no caching rather than failing the
  request.

### Notes

- Provider failures never raise. They are reported per provider in
  `status_by_provider`, so one bad API key cannot take down a search that another
  engine could answer.
- This gem succeeds the archived
  [`zarmeza/omnisearch-rails`](https://github.com/zarmeza/omnisearch-rails).
  The response shape carries over unchanged, as does the request shape apart from
  the wildcard rename under Changed above. Only the packaging differs, from a
  standalone Rails API app to a mountable engine. The cache is the other notable
  difference — the host's `Rails.cache` is used as-is, so there is no second
  database to prepare.
