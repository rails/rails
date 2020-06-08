# frozen_string_literal: true

require_relative "abstract_unit"

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

class BacktraceCleanerShouldNeverReturnEmpty < ActiveSupport::TestCase
  test "backtrace should return a backtrace no matter what" do
    @bc = ActiveSupport::BacktraceCleaner.new
    @bc.add_silencer { |line| true }

    bt = %w[ first second third ]

    assert_equal bt, @bc.clean(bt.dup)
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

class BacktraceCleanerDefaultFilterAndSilencerTest < ActiveSupport::TestCase
  def setup
    @bc = ActiveSupport::BacktraceCleaner.new
  end

  test "should format installed gems correctly" do
    backtrace = [ "#{Gem.default_dir}/gems/nosuchgem-1.2.3/lib/foo.rb" ]
    result = @bc.clean(backtrace, :all)
    assert_equal "nosuchgem (1.2.3) lib/foo.rb", result[0]
  end

  test "should format installed gems not in Gem.default_dir correctly" do
    target_dir = Gem.path.detect { |p| p != Gem.default_dir }
    # skip this test if default_dir is the only directory on Gem.path
    if target_dir
      backtrace = [ "#{target_dir}/gems/nosuchgem-1.2.3/lib/foo.rb" ]
      result = @bc.clean(backtrace, :all)
      assert_equal "nosuchgem (1.2.3) lib/foo.rb", result[0]
    end
  end

  test "should format gems installed by bundler" do
    backtrace = [ "#{Gem.default_dir}/bundler/gems/nosuchgem-1.2.3/lib/foo.rb" ]
    result = @bc.clean(backtrace, :all)
    assert_equal "nosuchgem (1.2.3) lib/foo.rb", result[0]
  end

  test "should silence gems from the backtrace" do
    backtrace = [ "#{Gem.path[0]}/gems/nosuchgem-1.2.3/lib/foo.rb", "other/file.rb" ]
    result = @bc.clean(backtrace)
    assert_equal %w[other/file.rb], result
  end

  test "should silence stdlib" do
    backtrace = ["#{RbConfig::CONFIG["rubylibdir"]}/lib/foo.rb", "other/file.rb"]
    result = @bc.clean(backtrace)
    assert_equal %w[other/file.rb], result
  end
end
