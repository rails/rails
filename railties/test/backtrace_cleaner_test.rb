# frozen_string_literal: true

require "abstract_unit"
require "rails/backtrace_cleaner"

class BacktraceCleanerTest < ActiveSupport::TestCase
  def setup
    @cleaner = Rails::BacktraceCleaner.new
  end

  test "should format installed gems correctly" do
    backtrace = [ "#{Gem.path[0]}/gems/nosuchgem-1.2.3/lib/foo.rb" ]
    result = @cleaner.clean(backtrace, :all)
    assert_equal "nosuchgem (1.2.3) lib/foo.rb", result[0]
  end

  test "should format installed gems not in Gem.default_dir correctly" do
    target_dir = Gem.path.detect { |p| p != Gem.default_dir }
    # skip this test if default_dir is the only directory on Gem.path
    if target_dir
      backtrace = [ "#{target_dir}/gems/nosuchgem-1.2.3/lib/foo.rb" ]
      result = @cleaner.clean(backtrace, :all)
      assert_equal "nosuchgem (1.2.3) lib/foo.rb", result[0]
    end
  end

  test "should consider traces from irb lines as User code" do
    backtrace = [ "(irb):1",
                  "/Path/to/rails/railties/lib/rails/commands/console.rb:77:in `start'",
                  "bin/rails:4:in `<main>'" ]
    result = @cleaner.clean(backtrace)
    assert_equal "(irb):1", result[0]
    assert_equal 1, result.length
  end
end
