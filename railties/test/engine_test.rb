require "abstract_unit"

class EngineTest < ActiveSupport::TestCase
  test "reports routes as available only if they're actually present" do
    engine = Class.new(Rails::Engine) do
      def initialize(*args)
        @routes = nil
        super
      end
    end

    assert !engine.routes?
  end

  def test_application_can_be_subclassed
    klass = Class.new(Rails::Application) do
      attr_reader :hello
      def initialize
        @hello = "world"
        super
      end
    end
    assert_equal "world", klass.instance.hello
  end
end
