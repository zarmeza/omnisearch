# frozen_string_literal: true

module Omnisearch
  # A search request and its results.
  #
  # `engine` selects which providers run. It accepts a provider name, a list of
  # them, or "all" for every registered one — see Omnisearch::EngineSelection,
  # which owns that rule. Validation happens here rather than in a model class so
  # the engine works in any host, ActiveModel or not.
  #
  #   query = Omnisearch::Query.new(engine: 'google', text: 'rails')
  #   query.valid?              #=> true
  #   query.results             #=> { query:, status:, status_by_provider:, results: }
  class Query
    # `engine` reads back as the normalized Array of names, whatever was passed
    # in — same rule as `error_messages`, which is always an array too.
    attr_reader :engine, :text, :errors

    def initialize(engine:, text:, config: nil, cache: nil, registry: nil)
      @selection = EngineSelection.new(engine, registry: registry)
      @engine = @selection.names
      @text = text.to_s
      @config = config
      @cache = cache
      @errors = {}
      validate
    end

    def valid?
      @errors.empty?
    end

    # The public response shape. Keys match the API this engine grew out of.
    def results
      return nil unless valid?

      responses = provider_results
      {
        query: text,
        status: aggregate_status(responses),
        status_by_provider: status_by_provider(responses),
        results: aggregate_results(responses)
      }
    end

    # What this query will actually run, in the order it will run them.
    #
    # Differs from `engine` in exactly one case: `engine` is `[:all]` where this
    # is `[:google, :bing]`. Everywhere else they are the same array.
    def providers
      @selection.providers
    end

    private

    def validate
      error = @selection.error
      @errors[:engine] = error if error
      @errors[:text] = 'is required' if text.strip.empty?
    end

    def provider_results
      providers.filter_map do |provider_name|
        provider = registry.fetch(provider_name)
        provider.call(text, config: config, cache: cache_instance)
      rescue StandardError => e
        # Registry#fetch raises on an unknown name; a provider raising is
        # already handled inside Provider.call. This is the backstop.
        { provider: provider_name, status: :error, error_messages: ["#{e.class}: #{e.message}"], data: [] }
      end
    end

    def aggregate_status(responses)
      responses.any? { |r| r[:status] == :ok } ? :ok : :service_unavailable
    end

    # Always an array per provider, so a caller can iterate without checking
    # for nil — including when the provider succeeded and has nothing to report.
    def status_by_provider(responses)
      responses.map do |response|
        {
          provider: response[:provider],
          status: response[:status],
          error_messages: Array(response[:error_messages])
        }
      end
    end

    # Merges every provider's results, dropping duplicates by link so a page
    # ranked by both engines appears once. When several providers return the same
    # link, the first one in `providers` order wins — so a caller that lists
    # providers explicitly controls which one it gets.
    def aggregate_results(responses)
      responses.flat_map { |response| response[:data] }
               .uniq { |result| result[:link] }
    end

    def config
      @config ||= Omnisearch.config
    end

    def cache_instance
      @cache_instance ||= Omnisearch::Cache.new
    end

    def registry
      @registry ||= Omnisearch.registry
    end
  end
end
