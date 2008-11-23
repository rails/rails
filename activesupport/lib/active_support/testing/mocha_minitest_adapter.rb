class MiniTest::Unit::TestCase
  include Mocha::Standalone

  class MochaAssertionCounter
    def initialize(runner) @runner = runner end
    def increment; @runner.assertion_count += 1 end
  end

  def run(runner)
    assertion_counter = MochaAssertionCounter.new(runner)
    result = '.'
    begin
      begin
        @passed = nil
        setup
        __send__ name
        mocha_verify(assertion_counter)
        @passed = true
      rescue Exception => e
        @passed = false
        result = runner.puke(self.class, self.name, e)
      ensure
        begin
          teardown
        rescue Exception => e
          result = runner.puke(self.class, self.name, e)
        end
      end
    ensure
      mocha_teardown
    end
    result
  end
end

module Test
  module Unit
    remove_const :TestCase

    class TestCase < MiniTest::Unit::TestCase
      include Test::Unit::Assertions
      def self.test_order; :sorted end
    end
  end
end
