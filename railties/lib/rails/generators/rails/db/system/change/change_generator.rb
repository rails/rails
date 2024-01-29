# frozen_string_literal: true

require "rails/generators/base"

module Rails
  module Generators
    module Db
      module System
        class ChangeGenerator < Base # :nodoc:
          include Database
          include Devcontainer
          include AppName

          class_option :to, required: true,
            desc: "The database system to switch to."

          def self.default_generator_root
            path = File.expand_path(File.join(base_name, "app"), base_root)
            path if File.exist?(path)
          end

          def initialize(*)
            super

            unless DATABASES.include?(options[:to])
              raise Error, "Invalid value for --to option. Supported preconfigurations are: #{DATABASES.join(", ")}."
            end

            opt = options.dup
            opt[:database] ||= opt[:to]
            self.options = opt.freeze
          end

          def edit_database_config
            template("config/databases/#{options[:database]}.yml", "config/database.yml")
          end

          def edit_gemfile
            name, version = gem_for_database
            gsub_file("Gemfile", all_database_gems_regex, name)
            gsub_file("Gemfile", gem_entry_regex_for(name), gem_entry_for(name, *version))
          end

          def edit_dockerfile
            dockerfile_path = File.expand_path("Dockerfile", destination_root)
            return unless File.exist?(dockerfile_path)

            base_name = docker_for_database_base
            build_name = docker_for_database_build
            if base_name
              gsub_file("Dockerfile", all_docker_bases_regex, base_name)
            end
            if build_name
              gsub_file("Dockerfile", all_docker_builds_regex, build_name)
            end
          end

          def edit_devcontainer_files
            devcontainer_path = File.expand_path(".devcontainer", destination_root)
            return unless File.exist?(devcontainer_path)

            edit_devcontainer_json
            edit_compose_yaml
          end

          private
            def all_database_gems
              DATABASES.map { |database| gem_for_database(database) }
            end

            def all_docker_bases
              DATABASES.map { |database| docker_for_database_base(database).nil? ? nil : docker_for_database_base(database) }.compact!
            end

            def all_docker_builds
              DATABASES.map { |database| docker_for_database_build(database).nil? ? nil : docker_for_database_build(database) }.compact!
            end

            def all_database_gems_regex
              all_database_gem_names = all_database_gems.map(&:first)
              /(\b#{all_database_gem_names.join('\b|\b')}\b)/
            end

            def all_docker_bases_regex
              /(\b#{all_docker_bases.join('\b|\b')}\b)/
            end

            def all_docker_builds_regex
              /(\b#{all_docker_builds.join('\b|\b')}\b)/
            end

            def gem_entry_regex_for(gem_name)
              /^gem.*\b#{gem_name}\b.*/
            end

            def gem_entry_for(*gem_name_and_version)
              gem_name_and_version.map! { |segment| "\"#{segment}\"" }
              "gem #{gem_name_and_version.join(", ")}"
            end

            def edit_devcontainer_json
              devcontainer_json_path = File.expand_path(".devcontainer/devcontainer.json", destination_root)
              return unless File.exist?(devcontainer_json_path)

              container_env = JSON.parse(File.read(devcontainer_json_path))["containerEnv"]
              db_name = db_name_for_devcontainer

              if container_env["DB_HOST"]
                if db_name
                  container_env["DB_HOST"] = db_name
                else
                  container_env.delete("DB_HOST")
                end
              else
                if db_name
                  container_env["DB_HOST"] = db_name
                end
              end

              new_json = JSON.pretty_generate(container_env, indent: "  ", object_nl: "\n  ")

              gsub_file(".devcontainer/devcontainer.json", /("containerEnv"\s*:\s*){[^}]*}/, "\\1#{new_json}")
            end

            def edit_compose_yaml
              compose_yaml_path = File.expand_path(".devcontainer/compose.yaml", destination_root)
              return unless File.exist?(compose_yaml_path)

              compose_config = YAML.load_file(compose_yaml_path)

              db_service_names.each do |db_service_name|
                compose_config["services"].delete(db_service_name)
                compose_config["volumes"]&.delete("#{db_service_name}-data")
                compose_config["services"]["rails-app"]["depends_on"]&.delete(db_service_name)
              end

              db_service = db_service_for_devcontainer

              if db_service
                compose_config["services"].merge!(db_service)
                compose_config["volumes"] = { db_volume_name_for_devcontainer => nil }.merge(compose_config["volumes"] || {})
                compose_config["services"]["rails-app"]["depends_on"] = [
                  db_name_for_devcontainer,
                  compose_config["services"]["rails-app"]["depends_on"]
                ].flatten.compact
              end

              compose_config.delete("volumes") unless compose_config["volumes"]&.any?
              compose_config["services"]["rails-app"].delete("depends_on") unless compose_config["services"]["rails-app"]["depends_on"]&.any?

              File.write(compose_yaml_path, compose_config.to_yaml)
            end
        end
      end
    end
  end
end
