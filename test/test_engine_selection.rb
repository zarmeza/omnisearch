# frozen_string_literal: true

require_relative 'test_helper'

# The rule that turns an `engine` parameter into a validated provider list.
# Tested on its own because it is a self-contained decision, separate from
# running the search. The tests that matter for the HTTP wire format live in
# dummy/, since they go through a real Rails request.
class TestEngineSelection < OmnisearchTest
  # No stubs here. An EngineSelection is resolved from the registry without any
  # HTTP, which is the point of testing it apart from Query — nothing in this file
  # can reach the network even if a stub were forgotten.
  def selection(input)
    Omnisearch::EngineSelection.new(input)
  end

  def test_a_single_name
    assert_equal %i[google], selection('google').names
  end

  def test_a_name_can_be_a_symbol
    assert_equal %i[google], selection(:google).names
  end

  def test_all_resolves_to_every_registered_provider
    assert_equal %i[google bing], selection('all').providers
  end

  def test_all_picks_up_a_provider_registered_after_the_gem_loaded
    # The claim the rename rests on: the wildcard is the registry, not a pair.
    Omnisearch.register(ThirdProvider)

    assert_equal %i[google bing third], selection('all').providers
  end

  def test_all_does_not_change_names_only_providers
    assert_equal %i[all], selection('all').names
  end

  def test_a_comma_separated_list
    assert_equal %i[bing google], selection('bing,google').names
  end

  def test_an_array
    assert_equal %i[bing google], selection(%w[bing google]).names
  end

  def test_an_array_of_symbols
    assert_equal %i[bing google], selection(%i[bing google]).names
  end

  def test_a_nested_array_is_flattened
    assert_equal %i[bing google], selection([%w[bing], ['google']]).names
  end

  def test_whitespace_is_stripped
    assert_equal %i[bing google], selection(' bing , google ').names
  end

  def test_duplicates_collapse
    assert_equal %i[bing google], selection('bing,google,bing').names
  end

  def test_duplicates_across_an_array_collapse
    assert_equal %i[bing google], selection(%w[bing google bing]).names
  end

  def test_order_is_the_order_asked_for
    assert_equal %i[bing google], selection('bing,google').names
    assert_equal %i[google bing], selection('google,bing').names
  end

  def test_a_known_provider_is_valid
    assert selection('google').valid?
    assert selection('bing,google').valid?
    assert selection('all').valid?
  end

  def test_an_unknown_name_is_invalid_and_lists_the_alternatives
    error = selection('altavista').error

    assert_match(/not a registered provider/, error)
    assert_match(/:bing/, error)
  end

  def test_an_unknown_name_in_a_list_names_only_the_unknown_ones
    error = selection('google,altavista,zarait').error

    assert_match(/:altavista is not a registered provider/, error)
    assert_match(/:zarait is not a registered provider/, error)
    refute_match(/google is not a registered provider/, error)
  end

  def test_a_missing_or_blank_name_is_required
    assert_equal 'is required', selection(nil).error
    assert_equal 'is required', selection('').error
    assert_equal 'is required', selection('   ').error
    assert_equal 'is required', selection([]).error
    assert_equal 'is required', selection(',,,').error
  end

  def test_all_combined_with_a_name_is_invalid
    error = selection('all,google').error

    assert_match(/cannot be combined/, error)
    assert_match(/engine=all/, error)
  end

  def test_all_combined_with_a_name_in_an_array_is_invalid
    assert_match(/cannot be combined/, selection(%w[google all]).error)
  end

  def test_all_on_its_own_is_not_the_mixed_case
    assert_nil selection('all').error
  end

  def test_a_non_string_input_reports_the_shape_not_a_missing_list
    # `?engine[foo]=bar` arrives as a Hash. "is required" would be a lie.
    assert_match(/must be a provider name/, selection({ 'foo' => 'bar' }).error)
  end

  def test_a_nested_non_string_input_is_also_a_shape_error
    assert_match(/must be a provider name/, selection(['google', { 'foo' => 'bar' }]).error)
  end

  def test_a_registry_can_be_supplied
    registry = Omnisearch::Registry.new
    registry.register(Omnisearch::BingProvider)

    assert_equal %i[bing], Omnisearch::EngineSelection.new('all', registry: registry).providers
  end

  def test_errors_are_nil_when_valid
    assert_nil selection('google').error
    assert_nil selection('all').error
    assert_nil selection(%w[google bing]).error
  end
end
