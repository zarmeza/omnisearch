# frozen_string_literal: true

module Omnisearch
  # Bing, by scraping the HTML results page.
  #
  # No API key needed, which makes it the one engine that works out of the box —
  # handy for a first run and for a host app that wants a working default before
  # anyone has signed up for an API key.
  #
  # A User-Agent is sent because Bing serves a different page to obvious bots.
  class BingProvider < Provider
    BASE_URL = 'https://www.bing.com/search'
    DEFAULT_USER_AGENT = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 ' \
                         '(KHTML, like Gecko) Chrome/47.0.2526.106 Safari/537.36'

    def self.name(value = nil)
      @name = value.to_sym if value
      @name || :bing
    end

    def self.request_url(query, _config = Omnisearch.config)
      "#{BASE_URL}?q=#{ERB::Util.url_encode(query)}"
    end

    def self.headers(config = Omnisearch.config)
      { 'User-Agent' => config.for(:bing)[:user_agent] || DEFAULT_USER_AGENT }
    end

    def self.parse_response(body)
      Nokogiri::HTML(body)
    end

    def self.map_results(data)
      data.css('.b_algo h2 a').map do |link|
        { title: link.text.strip, link: link['href'] }
      end
    end
  end
end
