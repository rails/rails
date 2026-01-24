# frozen_string_literal: true

require_relative "abstract_unit"

module ActiveSupport
  class EditorTest < ActiveSupport::TestCase
    setup do
      Editor.reset
    end

    teardown do
      Editor.reset
    end

    def test_current
      with_env("EDITOR" => nil, "RAILS_EDITOR" => nil) do
        assert_nil Editor.current
      end

      with_env("EDITOR" => "mate", "RAILS_EDITOR" => nil) do
        assert_equal "txmt://open?url=file://foo.rb&line=42", Editor.current.url_for("foo.rb", 42)
      end

      with_env("EDITOR" => "mate", "RAILS_EDITOR" => "unknown") do
        assert_nil Editor.current
      end

      with_env("EDITOR" => "code", "RAILS_EDITOR" => "mate") do
        assert_equal "txmt://open?url=file://foo.rb&line=42", Editor.current.url_for("foo.rb", 42)
      end
    end

    private
      def with_env(kv)
        old_values = {}
        kv.each { |key, value| old_values[key], ENV[key] = ENV[key], value }
        yield
      ensure
        old_values.each { |key, value| ENV[key] = value }
        Editor.reset
      end
  end
end
