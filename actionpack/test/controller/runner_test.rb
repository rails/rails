# frozen_string_literal: true

require 'abstract_unit'
require 'action_dispatch/testing/integration'

module ActionDispatch
  class RunnerTest < ActiveSupport::TestCase
    class MyRunner
      include Integration::Runner

      def initialize(session)
        @integration_session = session
      end

      def hi; end
    end

    def test_respond_to?
      runner = MyRunner.new(Class.new { def x; end }.new)
      assert_respond_to runner, :hi
      assert_respond_to runner, :x
    end
  end
end
