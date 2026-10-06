# frozen_string_literal: true

require_relative 'test_helper'

class TestQuery < OmnisearchTest
  def setup
    super
    stub_google
    stub_bing
  end

  def test_a_registered_provider_with_text_is_valid
    assert query(engine: 'bing', text: 'rails').valid?
  end

  def test_an_unknown_provider_is_invalid_and_lists_the_alternatives
    q = query(engine: 'altavista', text: 'rails')

    refute q.valid?
    assert_match(/not a registered provider/, q.errors[:engine])
    assert_match(/:bing/, q.errors[:engine])
  end

  def test_blank_text_is_invalid
    q = query(engine: 'bing', text: '  ')

    refute q.valid?
    assert_equal 'is required', q.errors[:text]
  end

  def test_results_are_nil_when_invalid
    assert_nil query(engine: 'nope', text: 'x').results
  end

  def test_returns_the_documented_response_shape
    results = query(engine: 'bing', text: 'rails').results

    assert_equal %i[query status status_by_provider results], results.keys
    assert_equal 'rails', results[:query]
  end

  def test_status_is_ok_when_a_provider_succeeds
    assert_equal :ok, query(engine: 'bing', text: 'rails').results[:status]
  end

  def test_status_by_provider_reports_each_provider
    results = query(engine: 'both', text: 'rails').results

    assert_equal(%i[google bing], results[:status_by_provider].map { |p| p[:provider] })
  end

  def test_error_messages_is_always_an_array_even_on_success
    results = query(engine: 'bing', text: 'rails').results

    assert_equal [], results[:status_by_provider].first[:error_messages]
  end

  def test_both_runs_every_registered_provider
    assert_equal %i[google bing], query(engine: 'both', text: 'x').providers
  end

  def test_all_is_an_alias_for_both
    assert_equal %i[google bing], query(engine: 'all', text: 'x').providers
  end

  def test_results_are_deduplicated_by_link_across_providers
    shared = 'https://example.org/omnisearch'
    stub_google(body: { 'items' => [{ 'title' => 'G', 'link' => shared }] }.to_json)
    stub_bing(body: <<~HTML)
      <html><body><li class="b_algo"><h2><a href="#{shared}">B</a></h2></li></body></html>
    HTML

    results = query(engine: 'both', text: 'x').results

    assert_equal 1, results[:results].size
    assert_equal shared, results[:results].first[:link]
  end

  def test_a_failing_provider_does_not_stop_the_others
    stub_google(code: 403)

    results = query(engine: 'both', text: 'rails').results

    assert_equal :ok, results[:status]
    google = results[:status_by_provider].find { |p| p[:provider] == :google }
    assert_equal :error, google[:status]
    assert_match(/403/, google[:error_messages].first)
    refute_empty results[:results]
  end

  def test_status_is_service_unavailable_when_every_provider_fails
    stub_google(code: 500)
    stub_bing(code: 503)

    assert_equal :service_unavailable, query(engine: 'both', text: 'x').results[:status]
  end

  def test_an_unconfigured_provider_is_reported_as_unavailable_not_raised
    Omnisearch.configure { |config| config.providers = {} }

    results = query(engine: 'google', text: 'rails').results

    assert_equal :service_unavailable, results[:status]
    assert_equal :unavailable, results[:status_by_provider].first[:status]
    assert_match(/not configured/, results[:status_by_provider].first[:error_messages].first)
  end

  def test_a_provider_that_raises_is_contained
    Omnisearch::BingProvider.stub(:call, ->(*) { raise 'provider exploded' }) do
      results = query(engine: 'both', text: 'x').results

      assert_equal :ok, results[:status]
      bing = results[:status_by_provider].find { |p| p[:provider] == :bing }
      assert_equal :error, bing[:status]
      assert_match(/provider exploded/, bing[:error_messages].first)
    end
  end

  private

  # WebMock's `to_return` validates its keys and rejects `status_message:`, and
  # HTTParty's `message` comes back empty here — which is the real-world case the
  # engine now handles by always including the status code. So the stubs only
  # need status and body.
  def stub_google(body: GOOGLE_OK.to_json, code: 200)
    stub_request(:get, /customsearch/).to_return(status: code, body: body)
  end

  def stub_bing(body: BING_OK, code: 200)
    stub_request(:get, /bing\.com/).to_return(status: code, body: body)
  end
end
