# frozen_string_literal: true

require "active_support/core_ext/string/inflections"

module ActiveSupport
  module Dependencies
    module ZeitwerkIntegration # :nodoc: all
      module Decorations
        def clear
          Dependencies.unload_interlock do
            Rails.autoloaders.main.reload
          end
        end

        def constantize(cpath)
          ActiveSupport::Inflector.constantize(cpath)
        end

        def safe_constantize(cpath)
          ActiveSupport::Inflector.safe_constantize(cpath)
        end

        def autoloaded_constants
          (Rails.autoloaders.main.loaded + Rails.autoloaders.once.loaded).to_a
        end

        def autoloaded?(object)
          cpath = object.is_a?(Module) ? object.name : object.to_s
          Rails.autoloaders.any? { |autoloader| autoloader.loaded?(cpath) }
        end

        def verbose=(verbose)
          l = verbose ? logger || Rails.logger : nil
          Rails.autoloaders.each { |autoloader| autoloader.logger = l }
        end

        def unhook!
          :no_op
        end
      end

      module Inflector
        def self.camelize(basename, _abspath)
          basename.camelize
        end
      end

      class << self
        def take_over
          setup_autoloaders
          freeze_autoload_paths
          decorate_dependencies
        end

        private

          def setup_autoloaders
            Dependencies.autoload_paths.each do |autoload_path|
              # Zeitwerk only accepts existing directories in `push_dir` to
              # prevent misconfigurations.
              next unless File.directory?(autoload_path)

              if autoload_once?(autoload_path)
                Rails.autoloaders.once.push_dir(autoload_path)
              else
                Rails.autoloaders.main.push_dir(autoload_path)
              end
            end

            Rails.autoloaders.each(&:setup)
          end

          def autoload_once?(autoload_path)
            Dependencies.autoload_once_paths.include?(autoload_path) ||
            Gem.path.any? { |gem_path| autoload_path.to_s.start_with?(gem_path) }
          end

          def freeze_autoload_paths
            Dependencies.autoload_paths.freeze
            Dependencies.autoload_once_paths.freeze
          end

          def decorate_dependencies
            Dependencies.unhook!
            Dependencies.singleton_class.prepend(Decorations)
            Object.class_eval { alias_method :require_dependency, :require }
          end
      end
    end
  end
end
