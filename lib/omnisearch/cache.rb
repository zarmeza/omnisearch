# frozen_string_literal: true

module Omnisearch
  # A thin, failure-tolerant adapter over `Rails.cache`.
  #
  # The engine deliberately does *not* configure the cache store. The host app
  # decides: `config.cache_store` can be Solid Cache, Redis, memcached, or an
  # in-memory store, and the engine works with all of them without a special
  # database or configuration of its own.
  #
  # What this class adds is tolerance. `Rails.cache` raises when the store is
  # unavailable, and a cache that can take the API down is worse than no cache:
  # an uncached search costs one upstream HTTP request, a raised exception
  # costs the caller a 500. So every operation rescues and returns nil.
  #
  # Outside Rails (a plain Ruby script, a test with no cache configured) it
  # degrades to no caching rather than failing to load.
  class Cache
    DEFAULT_TTL = 900 # 15 minutes

    def initialize(store: nil, ttl: DEFAULT_TTL)
      @store = store || default_store
      @ttl = ttl
    end

    def get(key)
      @store.read(key)
    rescue StandardError => e
      warn_and_continue(e)
      nil
    end

    def set(key, value)
      @store.write(key, value, expires_in: @ttl)
    rescue StandardError => e
      warn_and_continue(e)
      nil
    end

    private

    # Falls back to a no-op store when Rails.cache is absent, so the engine is
    # usable in a plain Ruby context. ActiveSupport::Cache::NullStore is the
    # idiomatic choice and ships with Active Support.
    def default_store
      return ::Rails.cache if defined?(::Rails) && ::Rails.respond_to?(:cache) && ::Rails.cache

      require 'active_support/cache'
      ActiveSupport::Cache::NullStore.new
    end

    # Once per instance rather than once per operation, so a sustained outage
    # produces one log line per process instead of one per request.
    def warn_and_continue(error)
      return if @warned

      @warned = true
      return unless defined?(::Rails) && ::Rails.respond_to?(:logger)

      ::Rails.logger.warn("[Omnisearch::Cache] #{error.class}, continuing uncached: #{error.message}")
    end
  end
end
