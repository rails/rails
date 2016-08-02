require 'abstract_unit'
require 'action_controller/metal/strong_parameters'
require 'active_support/core_ext/string/strip'

class ParametersSerializationTest < ActiveSupport::TestCase
  setup do
    @old_permitted_parameters = ActionController::Parameters.always_permitted_parameters
    ActionController::Parameters.always_permitted_parameters = true
  end

  teardown do
    ActionController::Parameters.always_permitted_parameters = @old_permitted_parameters
  end

  test 'yaml serialization' do
    assert_equal <<-end_of_yaml.strip_heredoc, YAML.dump(ActionController::Parameters.new(key: :value))
      --- !ruby/object:ActionController::Parameters
      parameters: !ruby/hash:ActiveSupport::HashWithIndifferentAccess
        key: :value
      permitted: false
    end_of_yaml
  end

  test 'yaml deserialization' do
    params = ActionController::Parameters.new(key: :value)
    roundtripped = YAML.load(YAML.dump(params))

    assert_equal params, roundtripped
    assert_not roundtripped.permitted?
  end

  test 'yaml backwardscompatible with psych 2.0.8 format' do
    params = YAML.load <<-end_of_yaml.strip_heredoc
      --- !ruby/hash:ActionController::Parameters
      key: :value
    end_of_yaml

    assert_equal :value, params[:key]
    assert_not params.permitted?
  end

  test 'yaml backwardscompatible with psych 2.0.9+ format' do
    params = YAML.load(<<-end_of_yaml.strip_heredoc)
      --- !ruby/hash-with-ivars:ActionController::Parameters
      elements:
        key: :value
      ivars:
        :@permitted: false
    end_of_yaml

    assert_equal :value, params[:key]
    assert_not params.permitted?
  end
end
