require 'abstract_unit'

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
end
