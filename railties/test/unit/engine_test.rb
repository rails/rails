require 'abstract_unit'

module Unit
  class EngineTest < ActiveSupport::TestCase
    it "reports routes as available only if they're actually present" do
      engine = Class.new(Rails::Engine) do
        def initialize(*args)
          @routes = nil
          super
        end
      end

      assert !engine.routes?
    end

    it "does not add more paths to routes on each call" do
      engine = Class.new(Rails::Engine)

      engine.routes
      length = engine.routes.draw_paths.length

      engine.routes
      assert_equal length, engine.routes.draw_paths.length
    end
  end
end
