require 'action_controller/metal/strong_parameters'

class ParametersRequireTest < ActiveSupport::TestCase
  test "required parameters must be present not merely not nil" do
    assert_raises(ActionController::ParameterMissing) do
      ActionController::Parameters.new(person: {}).require(:person)
    end
  end
end
