# frozen_string_literal: true

require "rails/generators"
require "yaml"

module Rails
  module Generators
    module Github
      class CiGenerator < Base # :nodoc:
        class_option :bun_version, type: :string,
          desc: "Bun version to install in CI"

        class_option :ci_packages, type: :array, default: [],
          desc: "Additional packages to install in CI"

        class_option :database, enum: Database::DATABASES, type: :string, default: "sqlite3",
          desc: "Include configuration for selected database"

        class_option :skip_rubocop, type: :boolean, default: false,
          desc: "Skip RuboCop CI configuration"

        class_option :skip_brakeman, type: :boolean, default: false,
          desc: "Skip Brakeman CI configuration"

        class_option :skip_test, type: :boolean, default: false,
          desc: "Skip test CI configuration"

        class_option :skip_system_test, type: :boolean, default: false,
          desc: "Skip system tests CI configuration"

        class_option :skip_importmap, type: :boolean, default: false,
          desc: "Skip importmap CI configuration"

        class_option :skip_bun, type: :boolean, default: false,
          desc: "Skip Bun CI configuration"


        source_paths << File.expand_path(File.join(base_name, "app", "templates"), base_root)

        def create_cifiles
          empty_directory ".github/workflows"

          template "github/ci.yml", ".github/workflows/ci.yml"
          template "github/dependabot.yml", ".github/dependabot.yml"
        end

        private
          delegate :bun_version, :ci_packages, :quiet, :skip_rubocop?,
                   :skip_brakeman?, :skip_test?, :skip_system_test?,
                   :skip_importmap?, :skip_bun?, to: :options

          def database
            @database ||= Database.build(options[:database])
          end

          def database_service_yaml(**options)
            return unless service = database.ci.service

            { database.name => service }.to_yaml(**options).gsub("\n", "\n      ")[4..-1]
          end

          def database_url_yaml
            return unless url = database.ci.database_url
            { "DATABASE_URL" => url }.to_yaml[4..-1].delete("\n")
          end
      end
    end
  end
end
