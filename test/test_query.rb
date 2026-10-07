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
    results = query(engine: 'all', text: 'rails').results

    assert_equal(%i[google bing], results[:status_by_provider].map { |p| p[:provider] })
  end

  def test_error_messages_is_always_an_array_even_on_success
    results = query(engine: 'bing', text: 'rails').results

    assert_equal [], results[:status_by_provider].first[:error_messages]
  end

  def test_all_runs_every_registered_provider
    assert_equal %i[google bing], query(engine: 'all', text: 'x').providers
  end

  def test_all_picks_up_a_provider_registered_after_the_gem_loaded
    Omnisearch.register(ThirdProvider)

    assert_equal %i[google bing third], query(engine: 'all', text: 'x').providers
  end

  def test_a_list_searches_every_provider_it_names
    results = query(engine: 'google,bing', text: 'rails').results

    assert_equal(%i[google bing], results[:status_by_provider].map { |p| p[:provider] })
    assert_equal :ok, results[:status]
  end

  def test_a_list_searches_only_the_providers_it_names
    # Not `all` in disguise: a list of one runs one provider.
    results = query(engine: 'bing', text: 'rails').results

    assert_equal(%i[bing], results[:status_by_provider].map { |p| p[:provider] })
  end

  def test_the_first_provider_in_a_list_wins_a_duplicate_link
    duplicate_stubs

    results = query(engine: 'google,bing', text: 'x').results

    assert_equal 'G', results[:results].first[:title]
  end

  def test_reordering_a_list_changes_which_provider_wins_a_duplicate_link
    duplicate_stubs

    results = query(engine: 'bing,google', text: 'x').results

    assert_equal 'B', results[:results].first[:title]
  end

  def test_results_are_deduplicated_by_link_across_providers
    results = query(engine: 'all', text: 'x').results

    assert_equal 2, results[:results].size
    assert_equal(%w[https://example.org/omnisearch https://example.org/ruby],
                 results[:results].map { |r| r[:link] })
  end

  def test_an_unknown_provider_in_a_list_is_invalid
    q = query(engine: 'google,altavista', text: 'rails')

    refute q.valid?
    assert_match(/:altavista is not a registered provider/, q.errors[:engine])
  end

  def test_a_list_does_not_search_the_providers_it_named_when_one_is_unknown
    # All-or-nothing. A caller who asked for two engines needs to know they got
    # one, rather than a 200 that silently dropped a provider.
    assert_nil query(engine: 'google,altavista', text: 'rails').results
  end

  def test_engine_reader_returns_the_normalized_names
    assert_equal %i[google bing], query(engine: ' google , bing ', text: 'x').engine
    assert_equal %i[all], query(engine: 'all', text: 'x').engine
  end

  def test_a_failing_provider_does_not_stop_the_others
    stub_google(code: 403)

    results = query(engine: 'all', text: 'rails').results

    assert_equal :ok, results[:status]
    google = results[:status_by_provider].find { |p| p[:provider] == :google }
    assert_equal :error, google[:status]
    assert_match(/403/, google[:error_messages].first)
    refute_empty results[:results]
  end

  def test_status_is_service_unavailable_when_every_provider_fails
    stub_google(code: 500)
    stub_bing(code: 503)

    assert_equal :service_unavailable, query(engine: 'all', text: 'x').results[:status]
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
      results = query(engine: 'all', text: 'x').results

      assert_equal :ok, results[:status]
      bing = results[:status_by_provider].find { |p| p[:provider] == :bing }
      assert_equal :error, bing[:status]
      assert_match(/provider exploded/, bing[:error_messages].first)
    end
  end

  private

  # Both providers return the same single link, with distinct titles, so which
  # one survives deduplication is observable.
  def duplicate_stubs
    shared = 'https://example.org/shared'
    stub_google(body: { 'items' => [{ 'title' => 'G', 'link' => shared }] }.to_json)
    stub_bing(body: <<~HTML)
      <html><body><li class="b_algo"><h2><a href="#{shared}">B</a></h2></li></body></html>
    HTML
  end

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
