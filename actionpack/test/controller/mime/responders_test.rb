require 'abstract_unit'
require 'controller/fake_models'

class ResponderTest < ActionController::TestCase
  def test_class_level_respond_to
    e = assert_raises(NoMethodError) do
      Class.new(ActionController::Base) do
        respond_to :json
      end
    end

    assert_includes e.message, '`responders` gem'
    assert_includes e.message, '~> 2.0'
  end

  def test_respond_with
    klass = Class.new(ActionController::Base) do
      def index
        respond_with Customer.new("david", 13)
      end
    end

    @controller = klass.new

    e = assert_raises(NoMethodError) do
      get :index
    end

    assert_includes e.message, '`responders` gem'
    assert_includes e.message, '~> 2.0'
  end
end
