# frozen_string_literal: true

require "fileutils"
require "thor/actions"

module Rails
  module Generators
    module Actions
      class CreateMigration < Thor::Actions::CreateFile #:nodoc:
        def migration_dir
          File.dirname(@destination)
        end

        def migration_file_name
          @base.migration_file_name
        end

        def identical?
          exists? && File.binread(existing_migration) == render
        end

        def revoke!
          say_destination = exists? ? relative_existing_migration : relative_destination
          say_status :remove, :red, say_destination
          return unless exists?
          ::FileUtils.rm_rf(existing_migration) unless pretend?
          existing_migration
        end

        def relative_existing_migration
          base.relative_to_original_destination_root(existing_migration)
        end

        def existing_migration
          @existing_migration ||= begin
            @base.class.migration_exists?(migration_dir, migration_file_name) ||
            File.exist?(@destination) && @destination
          end
        end
        alias :exists? :existing_migration

        private
          def on_conflict_behavior # :doc:
            options = base.options.merge(config)
            if identical?
              say_status :identical, :blue, relative_existing_migration
            elsif options[:force]
              say_status :remove, :green, relative_existing_migration
              say_status :create, :green
              unless pretend?
                ::FileUtils.rm_rf(existing_migration)
                yield
              end
            elsif options[:skip]
              say_status :skip, :yellow
            else
              say_status :conflict, :red
              raise Error, "Another migration is already named #{migration_file_name}: " \
                "#{existing_migration}. Use --force to replace this migration " \
                "or --skip to ignore conflicted file."
            end
          end

          def say_status(status, color, message = relative_destination) # :doc:
            base.shell.say_status(status, message, color) if config[:verbose]
          end
      end
    end
  end
end
