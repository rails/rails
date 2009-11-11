require 'abstract_unit'

require 'initializer'
require 'rails/backtrace_cleaner'

if defined? Test::Unit::Util::BacktraceFilter
  class TestWithBacktrace
    include Test::Unit::Util::BacktraceFilter
    include Rails::BacktraceFilterForTestUnit
  end

  class BacktraceCleanerFilterTest < ActiveSupport::TestCase
    def setup
      @test = TestWithBacktrace.new
      @backtrace = [ './test/rails/benchmark_test.rb', './test/rails/dependencies.rb', '/opt/local/lib/ruby/kernel.rb' ]
    end
    
    test "test with backtrace should use the rails backtrace cleaner to clean" do
      Rails.stubs(:backtrace_cleaner).returns(stub(:clean))
      Rails.backtrace_cleaner.expects(:clean).with(@backtrace, nil)
      @test.send(:filter_backtrace, @backtrace)
    end
    
    test "filter backtrace should have the same arity as Test::Unit::Util::BacktraceFilter" do
      assert_nothing_raised do
        @test.send(:filter_backtrace, @backtrace, '/opt/local/lib')
      end
    end
  end
else
  $stderr.puts 'No BacktraceFilter for minitest'
end

class BacktraceCleanerVendorGemTest < ActiveSupport::TestCase
  def setup
    @cleaner = Rails::BacktraceCleaner.new
  end

  test "should format installed gems correctly" do
    @backtrace = [ "#{Gem.path[0]}/gems/nosuchgem-1.2.3/lib/foo.rb" ]
    @result = @cleaner.clean(@backtrace)
    assert_equal "nosuchgem (1.2.3) lib/foo.rb", @result[0]
  end

  test "should format installed gems not in Gem.default_dir correctly" do
    @target_dir = Gem.path.detect { |p| p != Gem.default_dir }
    # skip this test if default_dir is the only directory on Gem.path
    if @target_dir
      @backtrace = [ "#{@target_dir}/gems/nosuchgem-1.2.3/lib/foo.rb" ]
      @result = @cleaner.clean(@backtrace)
      assert_equal "nosuchgem (1.2.3) lib/foo.rb", @result[0]
    end
  end

  test "should format vendor gems correctly" do
    @backtrace = [ "#{Rails::GemDependency.unpacked_path}/nosuchgem-1.2.3/lib/foo.rb" ]
    @result = @cleaner.clean(@backtrace)
    assert_equal "nosuchgem (1.2.3) [v] lib/foo.rb", @result[0]
  end

end
