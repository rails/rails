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

      def test_generate_script_with_initial_prefix
        FileUtils.cd(destination_root)
        FileUtils.mkdir_p("script/my_folder")
        FileUtils.touch("script/my_folder/some_script.rb")

        run_generator ["my_folder/my_script", "--prefix"]

        assert_file "script/my_folder/001_my_script.rb"
      end

      def test_generate_script_with_next_prefix
        FileUtils.cd(destination_root)
        FileUtils.mkdir_p("script/my_folder")
        FileUtils.touch("script/my_folder/001_some_script.rb")

        run_generator ["my_folder/my_script", "--prefix"]

        assert_file "script/my_folder/002_my_script.rb"
      end

      def test_generate_script_with_overflowing_prefix
        FileUtils.cd(destination_root)
        FileUtils.mkdir_p("script/my_folder")
        FileUtils.touch("script/my_folder/999_some_script.rb")

        run_generator ["my_folder/my_script", "--prefix"]

        assert_file "script/my_folder/1000_my_script.rb"
      end
    end
  end
end
