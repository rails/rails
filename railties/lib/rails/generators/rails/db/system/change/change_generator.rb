# frozen_string_literal: true

require "rails/generators/base"
require "yaml"
require "json"

module Rails
  module Generators
    module Db
      module System
        class ChangeGenerator < Base # :nodoc:
          include AppName

          BASE_PACKAGES = %w( curl libjemalloc2 ).freeze
          BUILD_PACKAGES = %w( gcc g++ make git ).freeze
          APT_INSTALL_PACKAGES_REGEXP = /(?<=apt-get install --no-install-recommends -y )[^\s\\&;|#<>]+(?:[ \t]+[^\s\\&;|#<>]+)*/

          class_option :to, required: true,
            desc: "The database system to switch to."

          def self.default_generator_root
            path = File.expand_path(File.join(base_name, "app"), base_root)
            path if File.exist?(path)
          end

          def initialize(*)
            super

            unless Database::DATABASES.include?(options[:to])
              raise Error, "Invalid value for --to option. Supported preconfigurations are: #{Database::DATABASES.join(", ")}."
            end

            opt = options.dup
            opt[:database] ||= opt[:to]
            self.options = opt.freeze
          end

          def edit_database_config
            template(database.template, "config/database.yml")
          end

          def edit_gemfile
            name, version = database.gem
            gsub_file("Gemfile", all_database_gems_regex, name)
            gsub_file("Gemfile", gem_entry_regex_for(name), gem_entry_for(name, *version))
          end

          def edit_dockerfile
            dockerfile_path = File.expand_path("Dockerfile", destination_root)
            return unless File.exist?(dockerfile_path)

            gsub_file("Dockerfile", APT_INSTALL_PACKAGES_REGEXP) do |packages|
              docker_packages(packages)
            end
          end

          def edit_devcontainer_files
            return unless devcontainer?

            edit_devcontainer_json
            edit_compose_yaml
          end

          private
            def all_database_gems
              Database.all.map { |database| database.gem }
            end

            def docker_packages(package_list)
              packages = package_list.split

              if BUILD_PACKAGES.all? { |package| packages.include?(package) } || packages.include?("build-essential")
                database_packages = Database.all.filter_map(&:build_package)
                database_package = database.build_package
              elsif BASE_PACKAGES.all? { |package| packages.include?(package) }
                database_packages = Database.all.filter_map(&:base_package)
                database_package = database.base_package
              else
                return package_list
              end

              packages -= database_packages
              packages << database_package if database_package
              packages.sort.join(" ")
            end

            def all_database_gems_regex
              all_database_gem_names = all_database_gems.map(&:first)
              /(\b#{all_database_gem_names.join('\b|\b')}\b)/
            end

            def gem_entry_regex_for(gem_name)
              /^gem.*\b#{gem_name}\b.*/
            end

            def gem_entry_for(*gem_name_and_version)
              gem_name_and_version.map! { |segment| "\"#{segment}\"" }
              "gem #{gem_name_and_version.join(", ")}"
            end

            def edit_devcontainer_json
              return unless devcontainer_json

              update_devcontainer_db_host
              update_devcontainer_db_feature
            end

            def edit_compose_yaml
              compose_yaml_path = File.expand_path(".devcontainer/compose.yaml", destination_root)
              return unless File.exist?(compose_yaml_path)

              compose_config = YAML.load_file(compose_yaml_path)

              Database.all.each do |database|
                compose_config["services"].delete(database.name)
                compose_config["volumes"]&.delete(database.volume)
                compose_config["services"]["rails-app"]["depends_on"]&.delete(database.name)
              end

              if database.service
                compose_config["services"][database.name] = database.service
                compose_config["volumes"] = { database.volume => nil }.merge(compose_config["volumes"] || {})
                compose_config["services"]["rails-app"]["depends_on"] = [
                  database.name,
                  compose_config["services"]["rails-app"]["depends_on"]
                ].flatten.compact
              end

              compose_config.delete("volumes") unless compose_config["volumes"]&.any?
              compose_config["services"]["rails-app"].delete("depends_on") unless compose_config["services"]["rails-app"]["depends_on"]&.any?

              File.write(compose_yaml_path, compose_config.to_yaml)
            end

            def update_devcontainer_db_host
              container_env = devcontainer_json["containerEnv"]
              db_name = database.name

              if container_env["DB_HOST"]
                if database.service
                  container_env["DB_HOST"] = db_name
                else
                  container_env.delete("DB_HOST")
                end
              else
                if database.service
                  container_env["DB_HOST"] = db_name
                end
              end

              new_json = JSON.pretty_generate(container_env, indent: "  ", object_nl: "\n  ")

              gsub_file(".devcontainer/devcontainer.json", /("containerEnv"\s*:\s*)(.|\n)*?(^\s{2}})/, "\\1#{new_json}")
            end

            def update_devcontainer_db_feature
              features = devcontainer_json["features"]
              db_feature = database.feature

              Database.all.each do |database|
                features.delete(database.feature_name)
              end

              features.merge!(db_feature) if db_feature

              new_json = JSON.pretty_generate(features, indent: "  ", object_nl: "\n  ")

              gsub_file(".devcontainer/devcontainer.json", /("features"\s*:\s*)(.|\n)*?(^\s{2}})/, "\\1#{new_json}")
            end

            def devcontainer_json
              return unless File.exist?(devcontainer_json_path)

              @devcontainer_json ||= JSON.parse(File.read(devcontainer_json_path), allow_comments: true)
            end

            def devcontainer_json_path
              File.expand_path(".devcontainer/devcontainer.json", destination_root)
            end

            def database
              @database ||= Database.build(options[:database])
            end

            def devcontainer?
              return @devcontainer if defined?(@devcontainer)

              @devcontainer = File.exist?(File.expand_path(".devcontainer", destination_root))
            end
        end
      end
    end
  end
end
