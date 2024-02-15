# frozen_string_literal: true

require "abstract_unit"
require "rails/full_message_cleaner"

class FullMessageCleanerTest < ActiveSupport::TestCase
  def setup
    @root = self.method(self.name).source_location.first
    # anonymous class to override @root in order to pass the containerized tests
    cleaner ||= Class.new(Rails::FullMessageCleaner) do
      def initialize
        @root = @root
        super
      end
    end
    @cleaner = cleaner.new
  end

  test "#filter removes all backtrace lines that don't originate from the app code from a real error" do
    generate_error()
    rescue Exception => error
      backtrace = error.full_message.split("\n")
      result = @cleaner.filter(backtrace)
      assert_equal 3, result.length
  end

  test "#filter considers backtraces from irb lines as User code using full_message formatting from a real error" do
    generate_error()
    rescue Exception => error
      backtrace = error.full_message.split("\n")
      backtrace.insert(3, "\tfrom (irb):1:in `<main>'")
      result = @cleaner.filter(backtrace)
      assert_equal 4, result.length
  end

  test "#filter filters the root path out of the backtrace lines that are not silenced" do
    generate_error()
    rescue Exception => error
      backtrace = error.full_message.split("\n")
      assert backtrace[1].include?(@root)
      result = @cleaner.filter(backtrace)
      assert_not result[1].include?(@root)
  end

  test "#filter removes all backtrace lines that don't originate from the app code from a ruby 2 error" do
    backtrace = [
      "\t19: from arbtitrary_gem_path/gems/gems-1.3.1/lib/gem/invocation.rb:127:in `invoke_command'",
      "\t18: from arbitrary_non_root_path/command.rb:28:in `run'",
      "\t17: from /workspaces/rails/railties/test/arbitrary_file.rb:43:in `perform'",
      "\t16: from /workspaces/rails/railties/test/arbitrary_file:47:in `start'",
      "\t15: from /workspaces/rails/railties/test/arbitrary_file:53:in `start'",
      "(irb):1:in `<main>': undefined local variable or method `wow' for main:Object (NameError)"
    ]
    result = @cleaner.filter(backtrace)
    assert_equal 4, result.length
  end

  private
    def generate_error
      deep_error_context()
    end

    def deep_error_context
      raise Exception.new("A test error")
    end
end
