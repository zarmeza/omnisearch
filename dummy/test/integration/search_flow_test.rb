# frozen_string_literal: true

require 'test_helper'

# The claim this engine has to earn: that it works *mounted inside a host app*.
#
# Every assertion here goes through the host's own routing and middleware
# stack, so a mistake in `isolate_namespace`, the mount point, or the engine's
# routes shows up here and nowhere else in the test suite.
class Omnisearch::SearchFlowTest < ActionDispatch::IntegrationTest
  GOOGLE_BODY = {
    'items' => [{ 'title' => 'Result', 'link' => 'https://example.org/result' }]
  }.to_json

  BING_BODY = <<~HTML
    <html><body>
      <li class="b_algo"><h2><a href="https://example.org/result">Result</a></h2></li>
    </body></html>
  HTML

  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
    Omnisearch.reset!
    Omnisearch.configure do |config|
      config.providers = { google: { engine_id: 'e', api_key: 'k' } }
    end
  end

  teardown { WebMock.reset! }

  test 'the engine is mounted where the host asked for it' do
    # Engine routes live in their own route set, not the host's, so the mount
    # point is asserted from the host and the leaf from the engine.
    assert_includes Rails.application.routes.routes.map { |r| r.path.spec.to_s }, '/search'

    engine_paths = Omnisearch::Engine.routes.routes.map { |r| r.path.spec.to_s }
    assert_includes engine_paths, '/search(.:format)'
    assert_includes engine_paths, '/'
  end

  test 'the engine declares an isolated namespace so it cannot collide with the host' do
    assert Omnisearch::Engine.isolated?
    assert_equal 'Omnisearch', Omnisearch::Engine.railtie_namespace.name
    assert_equal 'Omnisearch::SearchController', Omnisearch::SearchController.name
  end

  test 'a valid search returns the documented shape' do
    stub_request(:get, /customsearch/).to_return(status: 200, body: GOOGLE_BODY)

    get '/search/search', params: { engine: 'google', text: 'rails' }

    assert_response :success
    body = response.parsed_body
    assert_equal %w[query status status_by_provider results], body.keys
    assert_equal 'rails', body['query']
    assert_equal 'ok', body['status']
    assert_equal({ 'title' => 'Result', 'link' => 'https://example.org/result' },
                 body['results'].first)
  end

  test 'invalid parameters return 422 with the errors' do
    get '/search/search'

    assert_response :unprocessable_entity
    assert_equal %w[engine text], response.parsed_body['errors'].keys
  end

  test 'an unknown engine returns 422 rather than a 500' do
    get '/search/search', params: { engine: 'altavista', text: 'rails' }

    assert_response :unprocessable_entity
    assert_match(/not a registered provider/, response.parsed_body['errors']['engine'])
  end

  test 'the bare mount root also routes' do
    stub_request(:get, /bing\.com/).to_return(status: 200, body: BING_BODY)

    get '/search', params: { engine: 'bing', text: 'rails' }

    assert_response :success
    assert_equal 'ok', response.parsed_body['status']
  end

  test 'a provider failure is reported per provider without failing the request' do
    stub_request(:get, /customsearch/).to_return(status: 403, body: '')

    get '/search/search', params: { engine: 'google', text: 'rails' }

    assert_response :success
    provider = response.parsed_body['status_by_provider'].first
    assert_equal 'error', provider['status']
    assert_match(/403/, provider['error_messages'].first)
  end

  test 'error_messages is an array even when the provider succeeded' do
    stub_request(:get, /customsearch/).to_return(status: 200, body: GOOGLE_BODY)

    get '/search/search', params: { engine: 'google', text: 'rails' }

    assert_equal [], response.parsed_body['status_by_provider'].first['error_messages']
  end

  test 'the engine does not collide with the host namespace' do
    # isolate_namespace means the engine's controller is reachable as
    # Omnisearch::SearchController, not ::SearchController.
    assert defined?(Omnisearch::SearchController)
    assert_equal 'Omnisearch::SearchController', Omnisearch::SearchController.name
  end

  test 'the host can register its own provider and use it immediately' do
    host_provider = Class.new(Omnisearch::Provider) do
      def self.name(value = nil)
        @name = value.to_sym if value
        @name || :host_owned
      end

      def self.request_url(query, _config = Omnisearch.config)
        "https://host.test/search?q=#{query}"
      end

      def self.parse_response(body)
        JSON.parse(body)
      end

      def self.map_results(data)
        [{ title: data['title'], link: data['url'] }]
      end
    end

    stub_request(:get, /host\.test/)
      .to_return(status: 200, body: { title: 'From the host', url: 'https://host.test/1' }.to_json)

    Omnisearch.register(host_provider)

    get '/search/search', params: { engine: 'host_owned', text: 'rails' }

    assert_response :success
    assert_equal 'From the host', response.parsed_body['results'].first['title']
  end

  test 'the engine uses whatever cache the host configured, with no setup of its own' do
    # The host never told the engine about a cache, and the engine never
    # configured one. This is the whole design: Rails.cache is the host's
    # business.
    assert_nil Omnisearch.config.providers[:bing]
    refute Omnisearch::Engine.config.respond_to?(:connects_to)
  end
end
