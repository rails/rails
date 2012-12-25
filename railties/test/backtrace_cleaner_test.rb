require 'abstract_unit'
require 'rails/backtrace_cleaner'

class BacktraceCleanerVendorGemTest < ActiveSupport::TestCase
  def setup
    @cleaner = Rails::BacktraceCleaner.new
  end

  test "should format installed gems correctly" do
    @backtrace = [ "#{Gem.path[0]}/gems/nosuchgem-1.2.3/lib/foo.rb" ]
    @result = @cleaner.clean(@backtrace, :all)
    assert_equal "nosuchgem (1.2.3) lib/foo.rb", @result[0]
  end

  test "should format installed gems not in Gem.default_dir correctly" do
    @target_dir = Gem.path.detect { |p| p != Gem.default_dir }
    # skip this test if default_dir is the only directory on Gem.path
    if @target_dir
      @backtrace = [ "#{@target_dir}/gems/nosuchgem-1.2.3/lib/foo.rb" ]
      @result = @cleaner.clean(@backtrace, :all)
      assert_equal "nosuchgem (1.2.3) lib/foo.rb", @result[0]
    end
  end
end
