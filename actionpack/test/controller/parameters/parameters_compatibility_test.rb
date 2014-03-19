require 'abstract_unit'
require 'action_dispatch/http/upload'
require 'action_controller/metal/strong_parameters'

# TODO: These test can be removed once we reach 5.0.0 milestone
class ParametersCompatibilityTest < ActiveSupport::TestCase
  def test_calling_undefined_method_proxy_to_hash_with_deprecation
    assert_deprecated do
      params = ActionController::Parameters.new('crab' => 'Senjougahara', 'snail' => 'Hachikuji')
      assert_equal({crab: 'Senjougahara', snail: 'Hachikuji'}, params.symbolize_keys)
    end
  end

  def test_calling_defined_method_does_not_show_deprecation
    assert_not_deprecated do
      ActionController::Parameters.new.to_h
    end
  end

  def test_calling_private_method_on_hash_does_not_work
    assert_raises NoMethodError do
      ActionController::Parameters.caller
    end
  end

  def test_respond_to_on_non_existance_method_proxy_to_hash_with_deprecation
    assert_deprecated do
      params = ActionController::Parameters.new
      assert params.respond_to?(:symbolize_keys)
    end
  end

  def test_respond_to_on_existance_method_does_not_show_deprecation
    assert_not_deprecated do
      params = ActionController::Parameters.new
      assert params.respond_to?(:to_h)
    end
  end

  def test_is_a_returns_true_when_passing_hash
    assert ActionController::Parameters.new.is_a?(Hash)
  end

  def test_kind_of_returns_true_when_passing_hash
    assert ActionController::Parameters.new.kind_of?(Hash)
  end
end
