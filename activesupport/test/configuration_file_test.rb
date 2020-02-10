# frozen_string_literal: true

require_relative "abstract_unit"

class ConfigurationFileTest < ActiveSupport::TestCase
  test "backtrace contain the path to the yaml" do
    Tempfile.create do |file|
      file.write("wrong: <%= foo %>")
      file.rewind

      error = assert_raises do
        ActiveSupport::ConfigurationFile.parse(file.path)
      end

      assert_match(file.path, error.backtrace.first)
    end
  end
end
