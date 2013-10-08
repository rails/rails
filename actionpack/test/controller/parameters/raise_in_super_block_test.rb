require 'abstract_unit'
require 'action_controller/metal/strong_parameters'

class BasicParametersTest < ActiveSupport::TestCase
  test 'KeyError in fetch block should not be coverd up when key is symbol' do
    params = ActionController::Parameters.new()
    err = assert_raises(KeyError){
      params.fetch(:missing_key){ {}.fetch(:also_missing) }
    }
    assert_match(/:also_missing$/, err.message)
  end

  test 'inner key super set of outer key should be handled correctly when keys are symbols' do
    params = ActionController::Parameters.new()
    err = assert_raises(KeyError){
      params.fetch(:missing_key){ {}.fetch(:another_missing_key) }
    }
    assert_match(/:another_missing_key$/, err.message)
  end

  test 'inner key sub set of outer key should be handled correctly when keys are symbols' do
    params = ActionController::Parameters.new()
    err = assert_raises(KeyError){
      params.fetch(:another_missing_key){ {}.fetch(:missing_key) }
    }
    assert_match(/:missing_key$/, err.message)
  end

  test 'KeyError in fetch block should not be coverd up when key is string' do
    params = ActionController::Parameters.new()
    err = assert_raises(KeyError){
      params.fetch('missing_key'){ {}.fetch('also_missing') }
    }
    assert_match(/"also_missing"$/, err.message)
  end

  test 'inner key super set of outer key should be handled correctly when keys are strings' do
    params = ActionController::Parameters.new()
    err = assert_raises(KeyError){
      params.fetch('missing_key'){ {}.fetch('another_missing_key') }
    }
    assert_match(/"another_missing_key"$/, err.message)
  end

  test 'inner key sub set of outer key should be handled correctly when keys are strings' do
    params = ActionController::Parameters.new()
    err = assert_raises(KeyError){
      params.fetch('another_missing_key'){ {}.fetch('missing_key') }
    }
    assert_match(/"missing_key"$/, err.message)
  end
end