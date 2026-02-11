# frozen_string_literal: true

# :markup: markdown

module TestUnit
  module Generators
    class FixturesGenerator < ::Rails::Generators::Base
      hide!
      source_root File.expand_path("templates", __dir__)

      def create_test_files
        template "fixtures.yml", "test/fixtures/active_storage/blobs.yml"
      end
    end
  end
end
