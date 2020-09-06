# frozen_string_literal: true

require 'abstract_unit'
require 'action_controller/metal/strong_parameters'

class ParametersMutatorsTest < ActiveSupport::TestCase
  setup do
    @params = ActionController::Parameters.new(
      person: {
        age: '32',
        name: {
          first: 'David',
          last: 'Heinemeier Hansson'
        },
        addresses: [{ city: 'Chicago', state: 'Illinois' }]
      }
    )
  end

  test 'delete retains permitted status' do
    @params.permit!
    assert_predicate @params.delete(:person), :permitted?
  end

  test 'delete retains unpermitted status' do
    assert_not_predicate @params.delete(:person), :permitted?
  end

  test 'delete returns the value when the key is present' do
    assert_equal '32', @params[:person].delete(:age)
  end

  test 'delete removes the entry when the key present' do
    @params[:person].delete(:age)
    assert_not @params[:person].key?(:age)
  end

  test 'delete returns nil when the key is not present' do
    assert_nil @params[:person].delete(:first_name)
  end

  test 'delete returns the value of the given block when the key is not present' do
    assert_equal 'David', @params[:person].delete(:first_name) { 'David' }
  end

  test 'delete yields the key to the given block when the key is not present' do
    assert_equal 'first_name: David', @params[:person].delete(:first_name) { |k| "#{k}: David" }
  end

  test 'delete_if retains permitted status' do
    @params.permit!
    assert_predicate @params.delete_if { |k| k == 'person' }, :permitted?
  end

  test 'delete_if retains unpermitted status' do
    assert_not_predicate @params.delete_if { |k| k == 'person' }, :permitted?
  end

  test 'extract! retains permitted status' do
    @params.permit!
    assert_predicate @params.extract!(:person), :permitted?
  end

  test 'extract! retains unpermitted status' do
    assert_not_predicate @params.extract!(:person), :permitted?
  end

  test 'keep_if retains permitted status' do
    @params.permit!
    assert_predicate @params.keep_if { |k, v| k == 'person' }, :permitted?
  end

  test 'keep_if retains unpermitted status' do
    assert_not_predicate @params.keep_if { |k, v| k == 'person' }, :permitted?
  end

  test 'reject! retains permitted status' do
    @params.permit!
    assert_predicate @params.reject! { |k| k == 'person' }, :permitted?
  end

  test 'reject! retains unpermitted status' do
    assert_not_predicate @params.reject! { |k| k == 'person' }, :permitted?
  end

  test 'select! retains permitted status' do
    @params.permit!
    assert_predicate @params.select! { |k| k != 'person' }, :permitted?
  end

  test 'select! retains unpermitted status' do
    assert_not_predicate @params.select! { |k| k != 'person' }, :permitted?
  end

  test 'slice! retains permitted status' do
    @params.permit!
    assert_predicate @params.slice!(:person), :permitted?
  end

  test 'slice! retains unpermitted status' do
    assert_not_predicate @params.slice!(:person), :permitted?
  end

  test 'transform_keys! retains permitted status' do
    @params.permit!
    assert_predicate @params.transform_keys! { |k| k }, :permitted?
  end

  test 'transform_keys! retains unpermitted status' do
    assert_not_predicate @params.transform_keys! { |k| k }, :permitted?
  end

  test 'transform_values! retains permitted status' do
    @params.permit!
    assert_predicate @params.transform_values! { |v| v }, :permitted?
  end

  test 'transform_values! retains unpermitted status' do
    assert_not_predicate @params.transform_values! { |v| v }, :permitted?
  end

  test 'deep_transform_keys! retains permitted status' do
    @params.permit!
    assert_predicate @params.deep_transform_keys! { |k| k }, :permitted?
  end

  test 'deep_transform_keys! retains unpermitted status' do
    assert_not_predicate @params.deep_transform_keys! { |k| k }, :permitted?
  end

  test 'compact retains permitted status' do
    @params.permit!
    assert_predicate @params.compact, :permitted?
  end

  test 'compact retains unpermitted status' do
    assert_not_predicate @params.compact, :permitted?
  end

  test 'compact! returns nil when no values are nil' do
    assert_nil @params.compact!
  end

  test 'compact! retains permitted status' do
    @params[:person] = nil
    @params.permit!
    assert_predicate @params.compact!, :permitted?
  end

  test 'compact! retains unpermitted status' do
    @params[:person] = nil
    assert_not_predicate @params.compact!, :permitted?
  end

  test 'compact_blank retains permitted status' do
    @params.permit!
    assert_predicate @params.compact_blank, :permitted?
  end

  test 'compact_blank retains unpermitted status' do
    assert_not_predicate @params.compact_blank, :permitted?
  end

  test 'compact_blank! retains permitted status' do
    @params.permit!
    assert_predicate @params.compact_blank!, :permitted?
  end

  test 'compact_blank! retains unpermitted status' do
    assert_not_predicate @params.compact_blank!, :permitted?
  end
end
