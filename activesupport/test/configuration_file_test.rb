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
end
