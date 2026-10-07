# frozen_string_literal: true

require 'erb'
require 'json'
require 'httparty'
require 'nokogiri'
require 'active_support'
require 'active_support/cache'

# Error must be defined before errors.rb, which subclasses it.
module Omnisearch
  class Error < StandardError; end
end

require_relative 'omnisearch/version'
require_relative 'omnisearch/errors'
require_relative 'omnisearch/registry'
require_relative 'omnisearch/provider'
require_relative 'omnisearch/configuration'
require_relative 'omnisearch/cache'
require_relative 'omnisearch/engine_selection'
require_relative 'omnisearch/query'
require_relative 'omnisearch/providers/google_provider'
require_relative 'omnisearch/providers/bing_provider'

# Omnisearch is a mountable search engine for Rails apps.
#
# The host app registers the providers it has credentials for, and mounts the
# engine to get a `/search` endpoint. Caching uses whatever `Rails.cache` is
# already configured as — the engine does not require a database or pick a
# store for you.
#
#   # config/initializers/omnisearch.rb
#   Omnisearch.configure do |c|
#     c.providers = { google: { engine_id: ENV['GOOGLE_ENGINE_ID'],
#                               api_key:  ENV['GOOGLE_API_KEY'] } }
#   end
#
#   Omnisearch.register(MyOwnProvider)   # optional
#
#   # config/routes.rb
#   mount Omnisearch::Engine => '/search'
module Omnisearch
  class << self
    def registry
      @registry ||= Registry.new
    end

    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
      config
    end

    # Register a provider class. Idempotent by name.
    def register(provider_class)
      registry.register(provider_class)
    end

    def registered?(name)
      registry.registered?(name)
    end

    # Run a search. Returns the same shape the JSON endpoint returns.
    def search(engine:, text:, **)
      Query.new(engine: engine, text: text, **).results
    end

    def default_providers
      [Omnisearch::GoogleProvider, Omnisearch::BingProvider]
    end

    # Reset global state. For tests, and for a host app reloading an initializer.
    def reset!
      @registry = Registry.new
      @config = Configuration.new
      default_providers.each { |provider| register(provider) }
    end
  end

  # Register the built-ins at load time rather than only in the railtie, so the
  # gem also works in a plain Ruby script or a console. The railtie initializer
  # repeats this on boot, which is idempotent.
  default_providers.each { |provider| register(provider) }
end

require_relative 'omnisearch/railtie' if defined?(Rails::Railtie)
