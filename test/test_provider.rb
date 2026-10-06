# frozen_string_literal: true

require_relative 'test_helper'

# The provider contract itself, exercised through a minimal subclass. The
# built-in providers are tested separately; this is about the base class.
class TestProvider < OmnisearchTest
  class StubProvider < Omnisearch::Provider
    def self.name(value = nil)
      @name = value.to_sym if value
      @name || :stub
    end

    def self.request_url(query, config = Omnisearch.config)
      "https://stub.test/search?q=#{query}&key=#{config.for(:stub)[:key]}"
    end

    def self.headers(config = Omnisearch.config)
      { 'X-Key' => config.for(:stub)[:key].to_s }
    end

    def self.parse_response(body)
      JSON.parse(body)
    end

    def self.map_results(data)
      (data['hits'] || []).map { |h| { title: h['t'], link: h['u'] } }
    end
  end

  def setup
    super
    Omnisearch.register(StubProvider)
    Omnisearch.configure { |c| c.providers = { stub: { key: 'k' } } }
  end

  def test_the_three_required_methods_raise_when_not_implemented
    bare = Class.new(Omnisearch::Provider)

    assert_raises(NotImplementedError) { bare.request_url('x', Omnisearch.config) }
    assert_raises(NotImplementedError) { bare.parse_response('') }
    assert_raises(NotImplementedError) { bare.map_results({}) }
  end

  def test_a_provider_is_available_by_default
    assert StubProvider.available?
  end

  def test_headers_are_optional_and_default_to_empty
    bare = Class.new(Omnisearch::Provider)

    assert_empty bare.headers(Omnisearch.config)
  end

  def test_call_returns_the_normalized_shape_on_success
    stub_request(:get, /stub\.test/).to_return(status: 200,
                                               body: { 'hits' => [{
                                                 't' => 'T', 'u' => 'https://x.test'
                                               }] }.to_json)

    result = StubProvider.call('ruby')

    assert_equal :stub, result[:provider]
    assert_equal :ok, result[:status]
    assert_empty result[:error_messages]
    assert_equal [{ title: 'T', link: 'https://x.test' }], result[:data]
  end

  def test_call_uses_the_configured_url_and_headers
    stub_request(:get, /stub\.test/).with(headers: { 'X-Key' => 'k' })
                                    .to_return(status: 200, body: '{"hits":[]}')

    StubProvider.call('ruby')

    assert_requested :get, /key=k/
  end

  def test_an_unavailable_provider_is_reported_without_raising
    unavailable = Class.new(StubProvider) do
      def self.name(value = nil)
        @name = value.to_sym if value
        @name || :offline
      end

      def self.available?(_config = Omnisearch.config) = false
    end

    result = unavailable.call('ruby')

    assert_equal :unavailable, result[:status]
    assert_match(/not configured/, result[:error_messages].first)
    assert_empty result[:data]
  end

  def test_a_non_200_becomes_an_error_status_carrying_the_code
    stub_request(:get, /stub\.test/).to_return(status: 429, body: '')

    result = StubProvider.call('ruby')

    assert_equal :error, result[:status]
    # The reason phrase is empty under WebMock, so the code must still appear.
    assert_match(/429/, result[:error_messages].first)
    assert_empty result[:data]
  end

  def test_an_exception_inside_a_provider_becomes_an_error_result_not_a_raise
    exploding = Class.new(StubProvider) do
      def self.name(value = nil)
        @name = value.to_sym if value
        @name || :exploding
      end

      def self.parse_response(_body) = raise(ArgumentError, 'bad body')
    end
    stub_request(:get, /stub\.test/).to_return(status: 200, body: 'anything')

    result = exploding.call('ruby')

    assert_equal :error, result[:status]
    assert_match(/ArgumentError: bad body/, result[:error_messages].first)
  end

  def test_a_transport_exception_becomes_an_error_result
    stub_request(:get, /stub\.test/).to_raise(Errno::ECONNREFUSED)

    result = StubProvider.call('ruby')

    assert_equal :error, result[:status]
    assert_match(/ECONNREFUSED/, result[:error_messages].first)
  end

  def test_a_successful_response_is_cached_and_the_second_call_skips_http
    store = ActiveSupport::Cache::MemoryStore.new
    cache = Omnisearch::Cache.new(store: store)
    body = { 'hits' => [{ 't' => 'T', 'u' => 'https://x.test' }] }.to_json
    stub_request(:get, /stub\.test/).to_return(status: 200, body: body)

    first = StubProvider.call('ruby', cache: cache)
    second = StubProvider.call('ruby', cache: cache)

    assert_equal first[:data], second[:data]
    assert_requested :get, /stub\.test/, times: 1
  end

  def test_an_error_response_is_not_cached
    store = ActiveSupport::Cache::MemoryStore.new
    cache = Omnisearch::Cache.new(store: store)
    stub_request(:get, /stub\.test/).to_return(status: 500, body: '')

    StubProvider.call('ruby', cache: cache)

    assert_nil store.read('stub:ruby')
  end
end
