require "abstract_unit"

class RunnerTest < ActiveSupport::TestCase
  test "runner preserves the setting of integration_session" do
    runner = Class.new do
      def before_setup

      end
    end.new

    runner.extend(ActionDispatch::Integration::Runner)
    runner.integration_session.host! "lvh.me"

    runner.before_setup

    assert_equal "lvh.me", runner.integration_session.host
  end
end
