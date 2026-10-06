# frozen_string_literal: true

module Omnisearch
  # Google Custom Search JSON API.
  #
  # Configure `engine_id` and `api_key` in the host app; without them this
  # provider reports itself unavailable rather than raising, so a partially
  # configured install still serves the other engines.
  class GoogleProvider < Provider
    BASE_URL = 'https://customsearch.googleapis.com/customsearch/v1'

    def self.name(value = nil)
      @name = value.to_sym if value
      @name || :google
    end

    def self.available?(config = Omnisearch.config)
      settings = config.for(:google)
      settings[:engine_id].to_s != '' && settings[:api_key].to_s != ''
    end

    def self.request_url(query, config = Omnisearch.config)
      settings = config.for(:google)
      "#{BASE_URL}?cx=#{settings[:engine_id]}&key=#{settings[:api_key]}&q=#{ERB::Util.url_encode(query)}"
    end

    def self.parse_response(body)
      JSON.parse(body)
    end

    def self.map_results(data)
      (data['items'] || []).map do |item|
        { title: item['title'], link: item['link'] }
      end
    end
  end
end
