# frozen_string_literal: true

require "rails/generators"
require "rails/generators/testing/behavior"
require "rails/generators/testing/setup_and_teardown"
require "rails/generators/testing/assertions"
require "fileutils"

module Rails
  module Generators
    # Disable color in output. Easier to debug.
    no_color!

    # This class provides a TestCase for testing generators. To set up, you need
    # just to configure the destination and set which generator is being tested:
    #
    #   class AppGeneratorTest < Rails::Generators::TestCase
    #     tests AppGenerator
    #     setup do
    #       self.class.destination Dir.mktmpdir("generators", Rails.root.join("tmp").to_s)
    #     end
    #     teardown { FileUtils.remove_entry(destination_root) }
    #   end
    #
    # The setup callback creates a fresh destination root for each test, and teardown
    # removes it after the test.
    class TestCase < ActiveSupport::TestCase
      include Rails::Generators::Testing::Behavior
      include Rails::Generators::Testing::SetupAndTeardown
      include Rails::Generators::Testing::Assertions
      include FileUtils
    end
  end
end
