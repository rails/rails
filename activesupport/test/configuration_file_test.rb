# frozen_string_literal: true

require_relative "abstract_unit"

class ConfigurationFileTest < ActiveSupport::TestCase
  test "backtrace contains yaml path" do
    Tempfile.create do |file|
      file.write("wrong: <%= foo %>")
      file.rewind

      error = assert_raises do
        ActiveSupport::ConfigurationFile.parse(file.path)
      end

      assert_match file.path, error.backtrace.first
    end
  end

  test "backtrace contains yaml path (when Pathname given)" do
    Tempfile.create do |file|
      file.write("wrong: <%= foo %>")
      file.rewind

      error = assert_raises do
        ActiveSupport::ConfigurationFile.parse(Pathname(file.path))
      end

      assert_match file.path, error.backtrace.first
    end
  end
end
