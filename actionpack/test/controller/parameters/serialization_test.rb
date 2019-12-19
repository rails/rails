# frozen_string_literal: true

require "abstract_unit"
require "action_controller/metal/strong_parameters"

class ParametersSerializationTest < ActiveSupport::TestCase
  setup do
    @old_permitted_parameters = ActionController::Parameters.permit_all_parameters
    ActionController::Parameters.permit_all_parameters = false
  end

  teardown do
    ActionController::Parameters.permit_all_parameters = @old_permitted_parameters
  end

  test "yaml serialization" do
    params = ActionController::Parameters.new(key: :value)
    yaml_dump = YAML.dump(params)
    assert_match("--- !ruby/object:ActionController::Parameters", yaml_dump)
    assert_match(/parameters: !ruby\/hash:ActiveSupport::HashWithIndifferentAccess\n\s+key: :value/, yaml_dump)
    assert_match("permitted: false", yaml_dump)
  end

  test "yaml deserialization" do
    params = ActionController::Parameters.new(key: :value)
    roundtripped = YAML.load(YAML.dump(params))

    assert_equal params, roundtripped
    assert_not_predicate roundtripped, :permitted?
  end

  test "yaml backwardscompatible with psych 2.0.8 format" do
    params = YAML.load <<~end_of_yaml
      --- !ruby/hash:ActionController::Parameters
      key: :value
    end_of_yaml

    assert_equal :value, params[:key]
    assert_not_predicate params, :permitted?
  end

  test "yaml backwardscompatible with psych 2.0.9+ format" do
    params = YAML.load(<<~end_of_yaml)
      --- !ruby/hash-with-ivars:ActionController::Parameters
      elements:
        key: :value
      ivars:
        :@permitted: false
    end_of_yaml

    assert_equal :value, params[:key]
    assert_not_predicate params, :permitted?
  end
end
