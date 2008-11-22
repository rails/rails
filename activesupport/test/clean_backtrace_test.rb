require 'abstract_unit'

class BacktraceCleanerFilterTest < ActiveSupport::TestCase
  def setup
    @bc = ActiveSupport::BacktraceCleaner.new
    @bc.add_filter { |line| line.gsub("/my/prefix", '') }
  end
  
  test "backtrace should not contain prefix when it has been filtered out" do
    assert_equal "/my/class.rb", @bc.clean([ "/my/prefix/my/class.rb" ]).first
  end
  
  test "backtrace should contain unaltered lines if they dont match a filter" do
    assert_equal "/my/other_prefix/my/class.rb", @bc.clean([ "/my/other_prefix/my/class.rb" ]).first
  end
  
  test "backtrace should filter all lines in a backtrace" do
    assert_equal \
      ["/my/class.rb", "/my/module.rb"], 
      @bc.clean([ "/my/prefix/my/class.rb", "/my/prefix/my/module.rb" ])
  end
end

class BacktraceCleanerSilencerTest < ActiveSupport::TestCase
  def setup
    @bc = ActiveSupport::BacktraceCleaner.new
    @bc.add_silencer { |line| line =~ /mongrel/ }
  end
  
  test "backtrace should not contain lines that match the silencer" do
    assert_equal \
      [ "/other/class.rb" ], 
      @bc.clean([ "/mongrel/class.rb", "/other/class.rb", "/mongrel/stuff.rb" ])
  end
end

class BacktraceCleanerFilterAndSilencerTest < ActiveSupport::TestCase
  def setup
    @bc = ActiveSupport::BacktraceCleaner.new
    @bc.add_filter   { |line| line.gsub("/mongrel", "") }
    @bc.add_silencer { |line| line =~ /mongrel/ }
  end
  
  test "backtrace should not silence lines that has first had their silence hook filtered out" do
    assert_equal [ "/class.rb" ], @bc.clean([ "/mongrel/class.rb" ])
  end
end