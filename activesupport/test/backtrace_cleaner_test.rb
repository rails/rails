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

  test "backtrace should contain unaltered lines if they don't match a filter" do
    assert_equal "/my/other_prefix/my/class.rb", @bc.clean([ "/my/other_prefix/my/class.rb" ]).first
  end

  test "#dup also copy filters" do
    copy = @bc.dup
    @bc.add_filter { |line| line.gsub("/other/prefix/", "") }

    assert_equal "my/class.rb", @bc.clean(["/other/prefix/my/class.rb"]).first
    assert_equal "/other/prefix/my/class.rb", copy.clean(["/other/prefix/my/class.rb"]).first
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

  test "#dup also copy silencers" do
    copy = @bc.dup

    @bc.add_silencer { |line| line.include?("puma") }
    assert_equal [], @bc.clean(["/puma/stuff.rb"])
    assert_equal ["/puma/stuff.rb"], copy.clean(["/puma/stuff.rb"])
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
    backtrace = [ "#{Gem.path[0]}/gems/nosuchgem-1.2.3/lib/foo.rb" ]
    result = @bc.clean(backtrace)
    assert_empty result
  end

  test "should silence stdlib" do
    backtrace = ["#{RbConfig::CONFIG["rubylibdir"]}/lib/foo.rb"]
    result = @bc.clean(backtrace)
    assert_empty result
  end

  test "should preserve lines that have a subpath matching a gem path" do
    backtrace = [Gem.default_dir, *Gem.path].map { |path| "/parent#{path}/gems/nosuchgem-1.2.3/lib/foo.rb" }

    assert_equal backtrace, @bc.clean(backtrace)
  end
end

class BacktraceCleanerFirstCleanFrameTest < ActiveSupport::TestCase
  def setup
    @bc = ActiveSupport::BacktraceCleaner.new
  end

  def invoke_first_clean_frame_defaults
    -> do
      @bc.first_clean_frame.tap { @line = __LINE__ + 1 }
    end.call
  end

  def invoke_first_clean_frame(kind = :silent)
    -> do
      @bc.first_clean_frame(kind).tap { @line = __LINE__ + 1 }
    end.call
  end

  test "returns the first clean frame (defaults)" do
    result = invoke_first_clean_frame_defaults
    assert_match(/\A#{__FILE__}:#@line:in [`'](#{self.class}#)?invoke_first_clean_frame_defaults[`']\z/, result)
  end

  test "returns the first clean frame (:silent)" do
    result = invoke_first_clean_frame(:silent)
    assert_match(/\A#{__FILE__}:#@line:in [`'](#{self.class}#)?invoke_first_clean_frame[`']\z/, result)
  end

  test "returns the first clean frame (:noise)" do
    @bc.add_silencer { true }
    result = invoke_first_clean_frame(:noise)
    assert_match(/\A#{__FILE__}:#@line:in [`'](#{self.class}#)?invoke_first_clean_frame[`']\z/, result)
  end

  test "returns the first clean frame (:any)" do
    result = invoke_first_clean_frame(:any) # fallback of the case statement
    assert_match(/\A#{__FILE__}:#@line:in [`'](#{self.class}#)?invoke_first_clean_frame[`']\z/, result)
  end

  test "returns nil if there is no clean frame" do
    @bc.add_silencer { true }
    assert_nil invoke_first_clean_frame_defaults
  end
end

class BacktraceCleanerFirstCleanLocationTest < ActiveSupport::TestCase
  def setup
    @bc = ActiveSupport::BacktraceCleaner.new
  end

  def invoke_first_clean_location_defaults
    -> do
      @bc.first_clean_location.tap { @line = __LINE__ + 1 }
    end.call
  end

  def invoke_first_clean_location(kind = :silent)
    -> do
      @bc.first_clean_location(kind).tap { @line = __LINE__ + 1 }
    end.call
  end

  test "returns the first clean location (defaults)" do
    location = invoke_first_clean_location_defaults

    assert_equal __FILE__, location.path
    assert_equal @line, location.lineno
  end

  test "returns the first clean location (:silent)" do
    location = invoke_first_clean_location(:silent)

    assert_equal __FILE__, location.path
    assert_equal @line, location.lineno
  end

  test "returns the first clean location (:noise)" do
    @bc.add_silencer { true }
    location = invoke_first_clean_location(:noise)

    assert_equal __FILE__, location.path
    assert_equal @line, location.lineno
  end

  test "returns the first clean location (:any)" do
    location = invoke_first_clean_location(:any) # fallback of the case statement

    assert_equal __FILE__, location.path
    assert_equal @line, location.lineno
  end

  test "returns nil if there is no clean location" do
    @bc.add_silencer { true }
    assert_nil invoke_first_clean_location_defaults
  end
end

class BacktraceCleanerCleanLocationsTest < ActiveSupport::TestCase
  def setup
    @bc = ActiveSupport::BacktraceCleaner.new
    @locations = indirect_caller_locations
  end

  # Adds a frame from this file to the call stack.
  def indirect_caller_locations
    caller_locations
  end

  test "returns all clean locations (defaults)" do
    cleaned_locations = @bc.clean_locations(@locations)
    assert_equal [__FILE__], cleaned_locations.map(&:path)
  end

  test "returns all clean locations (:silent)" do
    cleaned_locations = @bc.clean_locations(@locations, :silent)
    assert_equal [__FILE__], cleaned_locations.map(&:path)
  end

  test "returns all clean locations (:noise)" do
    cleaned_locations = @bc.clean_locations(@locations, :noise)
    assert_not_includes cleaned_locations.map(&:path), __FILE__
  end

  test "returns an empty array if there are no clean locations" do
    @bc.add_silencer { true }
    assert_equal [], @bc.clean_locations(@locations)
  end

  test "filters and silencers are applied" do
    @bc.remove_filters!
    @bc.remove_silencers!

    # We filter all locations as "foo", then we silence filtered strings that
    # are exactly "foo". If filters and silencers are correctly applied, we
    # should get no locations back.
    @bc.add_filter { "foo" }
    @bc.add_silencer { "foo" == _1 }

    assert_equal [], @bc.clean_locations(@locations)
  end
end
