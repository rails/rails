# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/devcontainer/devcontainer_generator"

module Rails
  module Generators
    class DevcontainerGeneratorTest < Rails::Generators::TestCase
      include GeneratorsTestHelper

      def test_generates_devcontainer_files
        run_generator

        assert_file ".devcontainer/compose.yaml"
        assert_file ".devcontainer/Dockerfile"
        assert_file ".devcontainer/devcontainer.json"
      end

      def test_default_json_has_no_mounts
        run_generator

        assert_devcontainer_json_file do |devcontainer_config|
          assert_nil devcontainer_config["mounts"]
        end
      end

      def test_dev_option_devcontainer_json_mounts_local_rails
        run_generator ["--dev"]

        assert_devcontainer_json_file do |devcontainer_json|
          mounts = devcontainer_json["mounts"].sole

          assert_equal "bind", mounts["type"]
          assert_equal Rails::Generators::RAILS_DEV_PATH, mounts["source"]
          assert_equal Rails::Generators::RAILS_DEV_PATH, mounts["target"]
        end
      end
    end
  end
end
