# frozen_string_literal: true

require "rails/generators/base"

module Rails
  module Generators
    module Db
      module System
        class ChangeGenerator < Base # :nodoc:
          include Database
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

          private
            def all_database_gems
              DATABASES.map { |database| gem_for_database(database) }
            end

            def all_database_gems_regex
              all_database_gem_names = all_database_gems.map(&:first)
              /(\b#{all_database_gem_names.join('\b|\b')}\b)/
            end

            def gem_entry_regex_for(gem_name)
              /^gem.*\b#{gem_name}\b.*/
            end

            def gem_entry_for(*gem_name_and_version)
              gem_name_and_version.map! { |segment| '"' + segment + '"' }
              "gem #{gem_name_and_version.join(", ")}"
            end
        end
      end
    end
  end
end
