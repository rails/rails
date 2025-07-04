# frozen_string_literal: true

require "abstract_unit"

class TraceToFileExtractorTest < ActionDispatch::IntegrationTest
  setup do
    @original_editor = ENV["EDITOR"]
    ENV["EDITOR"] = "atom"
  end

  teardown do
    ENV["EDITOR"] = @original_editor
  end

  test "trace to file extractor with exception in app code" do
    Rails.stub(:root, "/Users/john/projects/rails") do
      assert_equal "atom://core/open/file?filename=/Users/john/projects/rails/app/models/user.rb&line=191", ActionDispatch::TraceToFileExtractor.new("app/models/user.rb:191:in 'Integer#/'").call
      assert_equal "atom://core/open/file?filename=/Users/john/projects/rails/app/views/home/index.html.erb&line=2", ActionDispatch::TraceToFileExtractor.new("app/views/home/index.html.erb:2:in 'Integer#/'").call
      assert_equal "atom://core/open/file?filename=/Users/john/projects/rails/app/views/home/index.erb&line=2", ActionDispatch::TraceToFileExtractor.new("app/views/home/index.erb:2:in 'Integer#/'").call
      assert_equal "atom://core/open/file?filename=/Users/john/projects/rails/app/views/home/index.turbo_stream+mobile.erb&line=2", ActionDispatch::TraceToFileExtractor.new("app/views/home/index.turbo_stream+mobile.erb:2:in 'Integer#/'").call
      assert_equal "atom://core/open/file?filename=/Users/john/projects/rails/app/views/home/index.html.haml&line=2", ActionDispatch::TraceToFileExtractor.new("app/views/home/index.html.haml:2:in 'Integer#/'").call
      assert_equal "atom://core/open/file?filename=/Users/john/projects/rails/app/views/home/index.html.slim&line=2", ActionDispatch::TraceToFileExtractor.new("app/views/home/index.html.slim:2:in 'Integer#/'").call
      assert_equal "atom://core/open/file?filename=/Users/john/projects/rails/app/models/user.rb&line=4", ActionDispatch::TraceToFileExtractor.new("app/models/user.rb:4:in 'block in User.some_logic'").call
      assert_equal "atom://core/open/file?filename=/Users/john/projects/rails/app/models/user.rb&line=5", ActionDispatch::TraceToFileExtractor.new("app/models/user.rb:5:in 'block (2 levels) in User.some_logic'").call
    end
  end

  test "trace to file extractor when we have trace from the gem" do
    error_highlight_spec = Gem.loaded_specs["error_highlight"]
    puma_spec = Gem.loaded_specs["puma"]
    activerecord_spec = Gem.loaded_specs["activerecord"]

    Rails.stub(:root, "/Users/john/projects/rails") do
      assert_equal "atom://core/open/file?filename=#{error_highlight_spec.full_gem_path}/lib/abc.rb&line=24", ActionDispatch::TraceToFileExtractor.new("error_highlight (1.2.3) lib/abc.rb:24:in 'SomeClass#some_method'").call
      assert_equal "atom://core/open/file?filename=#{puma_spec.full_gem_path}/lib/puma/configuration.rb&line=279", ActionDispatch::TraceToFileExtractor.new("puma (6.6.0) lib/puma/configuration.rb:279:in 'Puma::Configuration::ConfigMiddleware#call'").call
      assert_equal "atom://core/open/file?filename=#{activerecord_spec.full_gem_path}/lib/active_record/dynamic_matchers.rb&line=22", ActionDispatch::TraceToFileExtractor.new("activerecord (8.0.2) lib/active_record/dynamic_matchers.rb:22:in 'ActiveRecord::DynamicMatchers#method_missing'").call
    end
  end

  test "trace to file extractor when we have trace with absolute path" do
    Rails.stub(:root, "/Users/john/projects/rails") do
      assert_equal "atom://core/open/file?filename=/Users/john/projects/rails/app/models/user.rb&line=111", ActionDispatch::TraceToFileExtractor.new("/Users/john/projects/rails/app/models/user.rb:111:in 'Integer#/'").call
    end
  end

  test "edge cases" do
    assert_nil ActionDispatch::TraceToFileExtractor.new("").call
    assert_nil ActionDispatch::TraceToFileExtractor.new(nil).call
    assert_nil ActionDispatch::TraceToFileExtractor.new("42").call
    assert_nil ActionDispatch::TraceToFileExtractor.new("hello world, how are you?").call
  end

  test "when editor is not set" do
    ActionDispatch::TraceToFileExtractor.stub(:editor, nil) do
      assert_nil ActionDispatch::TraceToFileExtractor.new("app/models/user.rb:191:in 'Integer#/'").call
    end
  end
end
