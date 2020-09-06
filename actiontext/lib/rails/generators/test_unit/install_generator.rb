# frozen_string_literal: true

module TestUnit
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def create_test_files
        template 'fixtures.yml', 'test/fixtures/action_text/rich_texts.yml'
      end
    end
  end
end
