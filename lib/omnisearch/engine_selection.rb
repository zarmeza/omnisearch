# frozen_string_literal: true

module Omnisearch
  # What a caller asked for, turned into a validated, ordered list of providers.
  #
  # Separated from Query because this is a self-contained rule about a parameter,
  # and keeping it out of Query leaves Query about running the search. The
  # accepted shapes:
  #
  #   'google'           one provider
  #   'google,bing'      a comma-separated list — how a list arrives over HTTP
  #   %w[google bing]    an Array, for the Ruby API
  #   'all'              every *registered* provider, not a hardcoded pair
  #
  #   selection = Omnisearch::EngineSelection.new('google,bing')
  #   selection.names        #=> [:google, :bing]
  #   selection.error        #=> nil
  #
  # Validation is all-or-nothing and happens up front. A caller who named three
  # providers and got one silently would have no way to tell, which is worse than
  # a 422 that names the problem.
  class EngineSelection
    # The wildcard. It resolves to whatever is registered, so a host app
    # registering a third provider widens `all` with no change here.
    EVERY = :all

    attr_reader :names

    def initialize(input, registry: nil)
      @input = input
      @registry = registry
      @names = normalize(input)
    end

    def valid?
      error.nil?
    end

    # The reason this selection is unusable, or nil when it is fine. A message
    # rather than a boolean, because every failure here is a 422 and the caller
    # needs to know which of several distinct mistakes they made.
    def error
      return shape_error unless normalizable?(@input)
      return 'is required' if names.empty?
      return mixed_wildcard_error if names.include?(EVERY) && names.many?

      unknown_names_error
    end

    # The providers this will actually run, in the order it will run them.
    # Differs from `names` in exactly one case: `names` is `[:all]` where this
    # is `[:google, :bing]`.
    def providers
      names == [EVERY] ? resolved_registry.names : names
    end

    private

    def unknown_names_error
      unknown = names.reject { |name| name == EVERY || resolved_registry.registered?(name) }
      return nil if unknown.empty?

      listed = unknown.map { |name| "#{name.inspect} is not a registered provider" }.join('; ')
      "#{listed}. Available: #{resolved_registry.names.inspect}"
    end

    def mixed_wildcard_error
      "#{EVERY.inspect} cannot be combined with other providers. " \
        "Use engine=#{EVERY} on its own — it already includes every registered provider."
    end

    def shape_error
      'must be a provider name, a comma-separated list of names, or "all"'
    end

    # Flattens, splits, strips, symbolizes and dedups, preserving the order the
    # caller asked for. Unrecognizable input normalizes to nothing, and is
    # reported by `error` as a shape problem rather than as an empty list.
    def normalize(value)
      case value
      when String, Symbol then split_names(value)
      when Array then value.flat_map { |item| normalize(item) }.uniq
      else []
      end
    end

    def split_names(value)
      value.to_s.split(',').map(&:strip).reject(&:empty?).map(&:to_sym).uniq
    end

    # A provider name is a String or Symbol. `engine=google,bing` arrives as one
    # String; `engine[]=google&engine[]=bing` arrives as an Array. A Hash, from
    # `?engine[foo]=bar`, is neither, and gets a message about the shape instead
    # of a misleading "is required".
    def normalizable?(value)
      case value
      when nil, String, Symbol then true
      when Array then value.all? { |item| normalizable?(item) }
      else false
      end
    end

    def resolved_registry
      @resolved_registry ||= @registry || Omnisearch.registry
    end
  end
end
