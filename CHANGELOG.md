# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

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
