# frozen_string_literal: true

require 'simplecov'

# The gem's own coverage, in case SimpleCov is available. Deliberately optional
# so the test suite does not depend on a dev-only gem.
if defined?(SimpleCov)
  SimpleCov.start do
    skip '/test/'
    skip '/gems/'
    # Runtime branches that only matter when a host app misconfigures things.
    skip 'lib/omnisearch/railtie.rb'
  end
end

require 'minitest/autorun'
require 'minitest/mock'
require 'logger'
require 'stringio'
require 'active_support/testing/time_helpers'
require 'webmock/minitest'
require 'nokogiri'

require_relative '../lib/omnisearch'

# Base class for the engine's tests.
#
# Two things every test needs:
#
# - Network disabled. A suite that reaches Google or Bing is a suite whose
#   failures belong to somebody else.
# - A clean registry and config, so one test registering a provider cannot leak
#   into the next.
class OmnisearchTest < Minitest::Test
  include ActiveSupport::Testing::TimeHelpers

  GOOGLE_OK = {
    'items' => [
      { 'title' => 'Omnisearch', 'link' => 'https://example.org/omnisearch' },
      { 'title' => 'Ruby', 'link' => 'https://example.org/ruby' }
    ]
  }.freeze

  # A third provider, for tests that need to prove `all` means the registry
  # rather than a hardcoded pair. Registered per-test, never globally.
  class ThirdProvider < Omnisearch::Provider
    name :third

    def self.request_url(query, _config = Omnisearch.config)
      "https://third.test/search?q=#{query}"
    end

    def self.parse_response(body) = JSON.parse(body)

    def self.map_results(data) = [{ title: data['title'], link: data['link'] }]
  end

  BING_OK = <<~HTML
    <html><body>
      <li class="b_algo"><h2><a href="https://example.org/omnisearch">Omnisearch</a></h2></li>
      <li class="b_algo"><h2><a href="https://example.org/ruby">Ruby</a></h2></li>
    </body></html>
  HTML

  def setup
    WebMock.disable_net_connect!
    Omnisearch.reset!
    Omnisearch.configure do |config|
      config.providers = {
        google: { engine_id: 'test-engine', api_key: 'test-key' }
      }
    end
  end

  def teardown
    WebMock.reset!
  end

  # A cache store that raises on every operation, standing in for an unavailable
  # Rails.cache. Used to prove a cache outage is never an exception.
  def broken_cache_store
    Class.new do
      def read(*) = raise(StandardError, 'cache unavailable')
      def write(*, **) = raise(StandardError, 'cache unavailable')
    end.new
  end

  def memory_cache(ttl: Omnisearch::Cache::DEFAULT_TTL)
    Omnisearch::Cache.new(store: ActiveSupport::Cache::MemoryStore.new, ttl: ttl)
  end

  def query(engine:, text: 'test', **)
    Omnisearch::Query.new(engine: engine, text: text, **)
  end
end
