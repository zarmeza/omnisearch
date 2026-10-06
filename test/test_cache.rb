# frozen_string_literal: true

require_relative 'test_helper'

class TestCache < OmnisearchTest
  def test_reads_through_to_the_store
    store = ActiveSupport::Cache::MemoryStore.new
    store.write('key', 'value')

    assert_equal 'value', Omnisearch::Cache.new(store: store).get('key')
  end

  def test_returns_nil_on_a_miss
    assert_nil Omnisearch::Cache.new(store: ActiveSupport::Cache::MemoryStore.new).get('nope')
  end

  def test_writes_with_the_ttl_so_the_entry_eventually_expires
    store = ActiveSupport::Cache::MemoryStore.new
    Omnisearch::Cache.new(store: store, ttl: 60).set('key', 'value')

    assert_equal 'value', store.read('key')
    # Travel past the TTL rather than inspecting ActiveSupport's internals,
    # whose accessor names are not stable across versions.
    travel(61) { assert_nil store.read('key') }
  end

  def test_a_longer_ttl_is_respected
    store = ActiveSupport::Cache::MemoryStore.new
    Omnisearch::Cache.new(store: store, ttl: 900).set('key', 'value')

    travel(61) { assert_equal 'value', store.read('key') }
  end

  def test_returns_nil_instead_of_raising_when_a_read_fails
    assert_nil Omnisearch::Cache.new(store: broken_cache_store).get('key')
  end

  def test_swallows_a_write_failure
    assert_nil Omnisearch::Cache.new(store: broken_cache_store).set('key', 'value')
  end

  def test_a_broken_store_does_not_raise_at_all
    cache = Omnisearch::Cache.new(store: broken_cache_store)

    assert_silent { cache.get('key') }
    assert_silent { cache.set('key', 'value') }
  end

  def test_logs_the_failure_once_per_instance_not_once_per_operation
    # A real Logger pointed at a StringIO, rather than a Mock. The Cache only
    # calls `warn`, and a Logger satisfies that plus anything else a Rails boot
    # might emit, so the test does not have to enumerate methods.
    io = StringIO.new
    recorder = Logger.new(io)
    recorder.level = Logger::WARN

    with_rails_logger(recorder) do
      cache = Omnisearch::Cache.new(store: broken_cache_store)
      5.times { cache.get('key') }
    end

    lines = io.string.lines.grep(/Omnisearch::Cache/)

    assert_equal 1, lines.size, "expected one warning, got: #{lines.inspect}"
    assert_match(/continuing uncached/, lines.first)
  end

  def test_falls_back_to_a_null_store_when_rails_is_absent
    # No Rails constant in this process, so `default_store` must not blow up.
    assert_equal [], Omnisearch::Cache.new.get('key').to_a
  end

  def test_a_search_still_works_when_the_cache_is_broken
    stub_request(:get, /bing\.com/).to_return(status: 200, body: BING_OK)

    results = Omnisearch::Query.new(
      engine: 'bing', text: 'rails', cache: Omnisearch::Cache.new(store: broken_cache_store)
    ).results

    assert_equal :ok, results[:status]
    refute_empty results[:results]
  end

  private

  # Swap in a Rails module whose `logger` is the recorder, then restore it. Built
  # as a real Module rather than a constant leak, so ordering between tests
  # cannot matter.
  def with_rails_logger(logger)
    was_defined = Object.const_defined?(:Rails)
    previous = was_defined ? Object.const_get(:Rails) : nil
    previous_cache = (Rails.cache if was_defined && Rails.respond_to?(:cache))

    fake_rails = Module.new do
      define_singleton_method(:logger) { logger }
      define_singleton_method(:cache) { previous_cache }
    end
    Object.send(:remove_const, :Rails) if was_defined
    Object.const_set(:Rails, fake_rails)
    yield
  ensure
    Object.send(:remove_const, :Rails) if Object.const_defined?(:Rails)
    Object.const_set(:Rails, previous) if was_defined
  end
end
