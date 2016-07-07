require 'abstract_unit'
require 'action_controller/metal/strong_parameters'

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
        addresses: [{city: 'Chicago', state: 'Illinois'}]
      }
    )
  end

  test "changes on a duplicate do not affect the original" do
    dupped_params = @params.dup
    dupped_params.delete(:person)
    assert_not_equal @params, dupped_params
  end
end
