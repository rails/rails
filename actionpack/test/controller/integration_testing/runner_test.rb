require "abstract_unit"
require "action_dispatch/integration_testing/runner"

module ActionDispatch
  module IntegrationTesting
    class RunnerTest < ActiveSupport::TestCase
      class MyRunner
        include IntegrationTesting::Runner

        def initialize(session)
          @integration_session = session
        end

        def hi; end
      end

      def test_respond_to?
        runner = MyRunner.new(Class.new { def x; end }.new)
        assert runner.respond_to?(:hi)
        assert runner.respond_to?(:x)
      end
    end
  end
end
