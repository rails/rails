require "abstract_unit"

class BacktraceCleanerFilterTest < ActiveSupport::TestCase
  def setup
    @bc = ActiveSupport::BacktraceCleaner.new
    @bc.add_filter { |line| line.gsub("/my/prefix", "") }
  end

  test "backtrace should filter all lines in a backtrace, removing prefixes" do
    assert_equal \
        ["/my/class.rb", "/my/module.rb"],
        @bc.clean(["/my/prefix/my/class.rb", "/my/prefix/my/module.rb"])
  end

  test "backtrace cleaner should allow removing filters" do
    @bc.remove_filters!
    assert_equal "/my/prefix/my/class.rb", @bc.clean(["/my/prefix/my/class.rb"]).first
  end

  test "backtrace should contain unaltered lines if they dont match a filter" do
    assert_equal "/my/other_prefix/my/class.rb", @bc.clean([ "/my/other_prefix/my/class.rb" ]).first
  end
end

class BacktraceCleanerSilencerTest < ActiveSupport::TestCase
  def setup
    @bc = ActiveSupport::BacktraceCleaner.new
    @bc.add_silencer { |line| line.include?("mongrel") }
  end

  test "backtrace should not contain lines that match the silencer" do
    assert_equal \
      [ "/other/class.rb" ],
      @bc.clean([ "/mongrel/class.rb", "/other/class.rb", "/mongrel/stuff.rb" ])
  end

  test "backtrace cleaner should allow removing silencer" do
    @bc.remove_silencers!
    assert_equal ["/mongrel/stuff.rb"], @bc.clean(["/mongrel/stuff.rb"])
  end
end

class BacktraceCleanerMultipleSilencersTest < ActiveSupport::TestCase
  def setup
    @bc = ActiveSupport::BacktraceCleaner.new
    @bc.add_silencer { |line| line.include?("mongrel") }
    @bc.add_silencer { |line| line.include?("yolo") }
  end

  test "backtrace should not contain lines that match the silencers" do
    assert_equal \
      [ "/other/class.rb" ],
      @bc.clean([ "/mongrel/class.rb", "/other/class.rb", "/mongrel/stuff.rb", "/other/yolo.rb" ])
  end

  test "backtrace should only contain lines that match the silencers" do
    assert_equal \
      [ "/mongrel/class.rb", "/mongrel/stuff.rb", "/other/yolo.rb" ],
      @bc.clean([ "/mongrel/class.rb", "/other/class.rb", "/mongrel/stuff.rb", "/other/yolo.rb" ],
                :noise)
  end
end

class BacktraceCleanerFilterAndSilencerTest < ActiveSupport::TestCase
  def setup
    @bc = ActiveSupport::BacktraceCleaner.new
    @bc.add_filter   { |line| line.gsub("/mongrel", "") }
    @bc.add_silencer { |line| line.include?("mongrel") }
  end

  test "backtrace should not silence lines that has first had their silence hook filtered out" do
    assert_equal [ "/class.rb" ], @bc.clean([ "/mongrel/class.rb" ])
  end
end
