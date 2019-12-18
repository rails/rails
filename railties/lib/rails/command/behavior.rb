# frozen_string_literal: true

require "active_support"

module Rails
  module Command
    module Behavior #:nodoc:
      extend ActiveSupport::Concern

      class_methods do
        # Remove the color from output.
        def no_color!
          Thor::Base.shell = Thor::Shell::Basic
        end

        # Track all command subclasses.
        def subclasses
          @subclasses ||= []
        end

        private
          # Prints a list of generators.
          def print_list(base, namespaces)
            return if namespaces.empty?
            puts "#{base.camelize}:"

            namespaces.each do |namespace|
              puts("  #{namespace}")
            end

            puts
          end

          # Receives namespaces in an array and tries to find matching generators
          # in the load path.
          def lookup(namespaces)
            paths = namespaces_to_paths(namespaces)

            paths.each do |raw_path|
              lookup_paths.each do |base|
                path = "#{base}/#{raw_path}_#{command_type}"

                begin
                  require path
                  return
                rescue LoadError => e
                  raise unless /#{Regexp.escape(path)}$/.match?(e.message)
                rescue Exception => e
                  warn "[WARNING] Could not load #{command_type} #{path.inspect}. Error: #{e.message}.\n#{e.backtrace.join("\n")}"
                end
              end
            end
          end

          # This will try to load any command in the load path to show in help.
          def lookup!
            $LOAD_PATH.each do |base|
              Dir[File.join(base, *file_lookup_paths)].each do |path|
                path = path.sub("#{base}/", "")
                require path
              rescue Exception
                # No problem
              end
            end
          end

          # Convert namespaces to paths by replacing ":" for "/" and adding
          # an extra lookup. For example, "rails:model" should be searched
          # in both: "rails/model/model_generator" and "rails/model_generator".
          def namespaces_to_paths(namespaces)
            paths = []
            namespaces.each do |namespace|
              pieces = namespace.split(":")
              path = pieces.join("/")
              paths << "#{path}/#{pieces.last}"
              paths << path
            end
            paths.uniq!
            paths
          end
      end
    end
  end
end
