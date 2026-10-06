# frozen_string_literal: true

require_relative 'test_helper'

class TestRegistry < OmnisearchTest
  class FakeProvider < Omnisearch::Provider
    def self.name(value = nil)
      @name = value.to_sym if value
      @name || :fake
    end
  end

  def test_registers_the_builtin_providers_at_load
    assert_includes Omnisearch.registry.names, :google
    assert_includes Omnisearch.registry.names, :bing
  end

  def test_register_accepts_a_subclass_and_exposes_its_name
    assert_equal FakeProvider, Omnisearch.register(FakeProvider)
    assert Omnisearch.registered?(:fake)
  end

  def test_register_refuses_a_class_that_is_not_a_provider
    error = assert_raises(ArgumentError) { Omnisearch.register(String) }

    assert_match(/must be a subclass/, error.message)
  end

  def test_registration_is_idempotent_by_name
    replacement = Class.new(FakeProvider)

    Omnisearch.register(FakeProvider)
    Omnisearch.register(replacement)

    assert_equal replacement, Omnisearch.registry.fetch(:fake)
  end

  def test_fetch_raises_with_a_list_of_registered_providers
    error = assert_raises(KeyError) { Omnisearch.registry.fetch(:nope) }

    # The message matters: a typo is the common cause, so it should list what
    # *is* available rather than just saying no.
    assert_match(/unknown provider :nope/, error.message)
    assert_match(/:google/, error.message)
  end

  def test_unregister_removes_a_provider
    Omnisearch.register(FakeProvider)
    Omnisearch.registry.unregister(:fake)

    refute Omnisearch.registered?(:fake)
  end

  def test_a_host_can_replace_a_builtin_provider
    replacement = Class.new(Omnisearch::GoogleProvider)

    Omnisearch.register(replacement)

    assert_equal replacement, Omnisearch.registry.fetch(:google)
    assert_equal Omnisearch.registry.size, 2
  end
end
