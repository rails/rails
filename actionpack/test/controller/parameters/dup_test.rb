# frozen_string_literal: true

require 'abstract_unit'
require 'action_controller/metal/strong_parameters'
require 'active_support/core_ext/object/deep_dup'

class ParametersDupTest < ActiveSupport::TestCase
  setup do
    ActionController::Parameters.permit_all_parameters = false

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

  test "a duplicate maintains the original's permitted status" do
    @params.permit!
    dupped_params = @params.dup
    assert_predicate dupped_params, :permitted?
  end

  test "a duplicate maintains the original's parameters" do
    @params.permit!
    dupped_params = @params.dup
    assert_equal @params.to_h, dupped_params.to_h
  end

  test "changes to a duplicate's parameters do not affect the original" do
    dupped_params = @params.dup
    dupped_params.delete(:person)
    assert_not_equal @params, dupped_params
  end

  test "changes to a duplicate's permitted status do not affect the original" do
    dupped_params = @params.dup
    dupped_params.permit!
    assert_not_equal @params, dupped_params
  end

  test 'deep_dup content' do
    dupped_params = @params.deep_dup
    dupped_params[:person][:age] = '45'
    dupped_params[:person][:addresses].clear

    assert_not_equal @params[:person][:age], dupped_params[:person][:age]
    assert_not_equal @params[:person][:addresses], dupped_params[:person][:addresses]
  end

  test 'deep_dup @permitted' do
    dupped_params = @params.deep_dup
    dupped_params.permit!

    assert_not_predicate @params, :permitted?
  end

  test 'deep_dup @permitted is being copied' do
    @params.permit!
    assert_predicate @params.deep_dup, :permitted?
  end
end
