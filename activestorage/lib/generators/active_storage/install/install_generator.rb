# frozen_string_literal: true

# :markup: markdown

module ActiveStorage
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      class_option :within_engine, type: :boolean, hide: true

      hook_for :test_framework, as: :fixtures

      def create_migrations
        command = "active_storage:install:migrations"
        command = "app:#{command}" if options[:within_engine]

        rails_command command, inline: true
      end
    end
  end
end
