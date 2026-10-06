# frozen_string_literal: true

module Omnisearch
  # Base class for a search provider.
  #
  # A provider knows three things: what it is called, how to turn a raw HTTP
  # body into something parseable, and how to map that into the normalized
  # result shape. Everything else — caching, aggregation, the HTTP request
  # itself, error handling — lives in the engine.
  #
  # Subclass and implement the three class methods:
  #
  #   class MyProvider < Omnisearch::Provider
  #     name :my_provider
  #
  #     def self.request_url(query, config) = "https://…?q=#{query}"
  #     def self.headers(config) = {}
  #
  #     def self.parse_response(body) = JSON.parse(body)
  #
  #     def self.map_results(data)
  #       (data['items'] || []).map { |i| { title: i['title'], link: i['link'] } }
  #     end
  #   end
  #
  #   Omnisearch.register(MyProvider)
  #
  # Then `Omnisearch::Query.new(engine: 'my_provider', text: 'ruby').results`
  # just works.
  class Provider
    class << self
      # The identifier a caller passes as `engine:`. Defaults to the class name
      # underscored, so `Omnisearch::Providers::Bing` is registered as `:bing`.
      def name(value = nil)
        @name = value.to_sym if value
        @name || default_name
      end

      def default_name
        name = self.name.split('::').last
        return name.underscore.to_sym if name.respond_to?(:underscore)

        name.downcase.to_sym
      end

      # True when this provider can actually run. A provider with no credentials
      # is registered but not available, and is reported as such rather than
      # raising mid-request.
      def available?(_config = Omnisearch.config)
        true
      end

      # URL to fetch for a query. Required.
      def request_url(_query, _config)
        raise NotImplementedError, "#{self}.request_url must be implemented"
      end

      # Raw body to something parseable. Required.
      def parse_response(_body)
        raise NotImplementedError, "#{self}.parse_response must be implemented"
      end

      # Parsed data to the normalized result shape. Required.
      #
      # Returns an array of { title:, link: }. Hosts can add their own keys;
      # they are passed through to the caller untouched.
      def map_results(_data)
        raise NotImplementedError, "#{self}.map_results must be implemented"
      end

      # Extra headers for the HTTP request. Optional.
      def headers(_config)
        {}
      end

      # Perform a search and return the normalized provider result.
      #
      # Returns a hash with :provider, :status, :error_messages and :data.
      # `status` is :ok, :error or :unavailable.
      def call(query, config: Omnisearch.config, cache: Omnisearch::Cache.new)
        unless available?(config)
          return {
            provider: name, status: :unavailable,
            error_messages: ["#{name} is not configured"], data: []
          }
        end

        cache_key = "#{name}:#{query}"
        cached = cache.get(cache_key)
        # The cache stores the raw response body, so it still has to go through
        # parse_response. Skipping that step passes a String to map_results,
        # which only works for the fetch path and breaks on every cache hit.
        return { provider: name, status: :ok, error_messages: [], data: map_results(parse_response(cached)) } if cached

        perform(query, config, cache, cache_key)
      end

      private

      def perform(query, config, cache, cache_key)
        body = fetch_body(query, config)

        case body[:code]
        when 200
          results = map_results(parse_response(body[:body]))
          cache.set(cache_key, body[:body])
          { provider: name, status: :ok, error_messages: [], data: results }
        else
          { provider: name, status: :error, error_messages: [body[:message]], data: [] }
        end
      rescue StandardError => e
        # A provider must never take the whole search down. One provider failing
        # is reported in the aggregate; it does not become an exception.
        { provider: name, status: :error, error_messages: ["#{e.class}: #{e.message}"], data: [] }
      end

      # Always builds a usable message. `HTTParty::Response#message` is the
      # HTTP reason phrase, which is frequently empty — it is blank under WebMock
      # and behind several proxies — so the status code is always included and
      # the phrase is only added when there is one.
      def fetch_body(query, config)
        response = HTTParty.get(request_url(query, config), headers: headers(config))
        phrase = response.message.to_s.strip

        {
          code: response.code,
          body: response.body,
          message: phrase.empty? ? "HTTP #{response.code}" : "HTTP #{response.code}: #{phrase}"
        }
      end
    end
  end
end
