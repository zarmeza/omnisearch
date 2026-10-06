# frozen_string_literal: true

module Omnisearch
  # Configuration for the engine, set by the host app.
  #
  #   # config/initializers/omnisearch.rb
  #   Omnisearch.configure do |c|
  #     c.providers = { google: { engine_id: ENV['GOOGLE_ENGINE_ID'],
  #                               api_key: ENV['GOOGLE_API_KEY'] } }
  #   end
  #
  # Provider-specific settings live under the provider's own name, so adding a
  # provider does not require a change here. Anything is allowed in the hash —
  # a provider decides what it reads.
  class Configuration
    attr_accessor :providers, :cache_ttl
    attr_reader :results_per_engine

    def initialize
      @providers = {}
      @cache_ttl = Cache::DEFAULT_TTL
      @results_per_engine = 10
    end

    # Settings for one provider, always a Hash so a provider can call
    # `config[:api_key]` without a nil check.
    def for(provider_name)
      providers[provider_name.to_sym] || {}
    end
  end
end
