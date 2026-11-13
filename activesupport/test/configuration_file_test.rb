# frozen_string_literal: true

require_relative "abstract_unit"

class ConfigurationFileTest < ActiveSupport::TestCase
  test "backtrace contains YAML path" do
    Tempfile.create do |file|
      file.write("wrong: <%= foo %>")
      file.flush

      error = assert_raises do
        ActiveSupport::ConfigurationFile.parse(file.path)
      end

      assert_match file.path, error.backtrace.first
    end
  end

  test "backtrace contains YAML path (when Pathname given)" do
    Tempfile.create do |file|
      file.write("wrong: <%= foo %>")
      file.flush

      error = assert_raises do
        ActiveSupport::ConfigurationFile.parse(Pathname(file.path))
      end

      assert_match file.path, error.backtrace.first
    end
  end

  test "load raw YAML" do
    Tempfile.create do |file|
      file.write("ok: 42")
      file.flush

      data = ActiveSupport::ConfigurationFile.parse(Pathname(file.path))
      assert_equal({ "ok" => 42 }, data)
    end
  end

  test "resolves aliases and common scalar classes" do
    Tempfile.create do |file|
      file.write(<<~YAML)
        default: &default
          pool: 5
        development:
          <<: *default
          made_on: 2024-01-01
          settings:
            :name: root
      YAML
      file.flush

      data = ActiveSupport::ConfigurationFile.parse(file.path)

      assert_equal 5, data.dig("development", "pool")
      assert_instance_of Date, data.dig("development", "made_on")
      assert_equal :name, data.dig("development", "settings").keys.first
    end
  end

  test "loads an ordered map" do
    Tempfile.create do |file|
      file.write("--- !omap\n- a:\n    id: 1\n")
      file.flush

      data = ActiveSupport::ConfigurationFile.parse(file.path)
      assert_equal 1, data.dig("a", "id")
    end
  end

  test "does not load an arbitrary ruby object" do
    Tempfile.create do |file|
      file.write("--- !ruby/object:Gem::Version\nversion: 1.2.3\n")
      file.flush

      assert_raises(Psych::DisallowedClass) do
        ActiveSupport::ConfigurationFile.parse(file.path)
      end
    end
  end

  test "raises FormatError for malformed YAML" do
    Tempfile.create do |file|
      file.write("foo: bar: baz\n")
      file.flush

      error = assert_raises(ActiveSupport::ConfigurationFile::FormatError) do
        ActiveSupport::ConfigurationFile.parse(file.path)
      end

      assert_match "YAML syntax error", error.message
    end
  end
end
