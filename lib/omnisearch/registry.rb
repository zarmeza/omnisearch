# frozen_string_literal: true

module Omnisearch
  # The set of providers this installation can use.
  #
  # Providers are registered by class and looked up by the name they declare, so
  # a host app can add its own without touching the engine:
  #
  #   Omnisearch.register(MyProvider)
  #   Omnisearch.registered?('my_provider')  #=> true
  #
  # Registration is idempotent: re-registering a name replaces it, which is what
  # you want when a host app overrides a built-in provider with its own subclass.
  class Registry
    def initialize
      @providers = {}
    end

    def register(provider_class)
      name = provider_class.name
      unless provider_class < Provider
        raise ArgumentError,
              "#{provider_class} must be a subclass of Omnisearch::Provider"
      end

      @providers[name] = provider_class
      provider_class
    end

    def unregister(name)
      @providers.delete(name.to_sym)
    end

    # Look up a provider class by name. Raises KeyError with a useful message
    # listing what *is* available, because the common cause is a typo.
    def fetch(name)
      key = name.to_sym
      return @providers[key] if @providers.key?(key)

      raise KeyError, "unknown provider #{key.inspect}. Registered: #{names.inspect}"
    end

    def [](name)
      @providers[name.to_sym]
    end

    def registered?(name)
      @providers.key?(name.to_sym)
    end

    def names
      @providers.keys
    end

    def each(&)
      @providers.each_value(&)
    end

    def clear
      @providers.clear
    end

    def size
      @providers.size
    end
  end
end
