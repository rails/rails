# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/script/script_generator"

module Rails
  module Generators
    class ScriptGeneratorTest < Rails::Generators::TestCase
      include GeneratorsTestHelper

      def test_generate_script
        run_generator ["my_script"]

        assert_file "script/my_script.rb" do |script|
          assert_match('require_relative "../config/environment"', script)
        end
      end

      def test_generate_script_with_folder
        run_generator ["my_folder/my_script"]

        assert_file "script/my_folder/my_script.rb" do |script|
          assert_match('require_relative "../../config/environment"', script)
        end
      end
    end
  end
end
