# frozen_string_literal: true

module Omnisearch
  # The Rails integration.
  #
  # An Engine rather than a Railtie because the gem ships its own controller and
  # routes, and those need to be namespaced so they cannot collide with the
  # host app's.
  #
  # Host apps mount it wherever they like:
  #
  #   mount Omnisearch::Engine => '/search'
  #
  # and get `GET /search?engine=google&text=ruby`.
  class Engine < ::Rails::Engine
    isolate_namespace Omnisearch

    config.omnisearch = ActiveSupport::OrderedOptions.new

    initializer 'omnisearch.default_providers' do
      # Re-register the built-ins on boot. Idempotent, so a host app that
      # registered a subclass of its own in an initializer is not clobbered as
      # long as its initializer runs first — which `after_initialize` ordering
      # cannot guarantee, hence the note in the README.
      Omnisearch.default_providers.each { |provider| Omnisearch.register(provider) }
    end

    initializer 'omnisearch.assets' do |app|
      if app.config.respond_to?(:assets) && app.config.assets.respond_to?(:precompile)
        app.config.assets.precompile += %w[omnisearch_manifest.js]
      end
    end
  end
end
