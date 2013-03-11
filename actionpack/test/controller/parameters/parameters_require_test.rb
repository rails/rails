require 'abstract_unit'
require 'action_controller/metal/strong_parameters'

class ParametersRequireTest < ActiveSupport::TestCase
  test "required parameters must be present" do
    assert_raises(ActionController::ParameterMissing) do
      ActionController::Parameters.new(name: {}).require(:person)
    end
  end

  test "required parameters can't be blank" do
    assert_raises(ActionController::EmptyParameter) do
      ActionController::Parameters.new(person: {}).require(:person)
    end
  end
end
