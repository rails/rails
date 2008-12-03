require 'abstract_unit'

require 'initializer'
require 'rails/backtrace_cleaner'

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
    @test.filter_backtrace(@backtrace)
  end
  
  test "filter backtrace should have the same arity as Test::Unit::Util::BacktraceFilter" do
    assert_nothing_raised do
      @test.filter_backtrace(@backtrace, '/opt/local/lib')
    end
  end
end