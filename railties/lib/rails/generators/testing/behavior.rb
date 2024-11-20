# frozen_string_literal: true

require "active_support/core_ext/class/attribute"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/hash/reverse_merge"
require "active_support/core_ext/kernel/reporting"
require "active_support/testing/stream"
require "active_support/concern"
require "rails/generators"

module Rails
  module Generators
    module Testing
      module Behavior
        extend ActiveSupport::Concern
        include ActiveSupport::Testing::Stream

        included do
          # Generators frequently change the current path using +FileUtils.cd+.
          # So we need to store the path at file load and revert back to it after each test.
          class_attribute :current_path, default: File.expand_path(Dir.pwd)
          class_attribute :default_arguments, default: []
          class_attribute :destination_root
          class_attribute :generator_class
        end

        module ClassMethods
          # Sets which generator should be tested:
          #
          #   tests AppGenerator
          def tests(klass)
            self.generator_class = klass
          end

          # Sets default arguments on generator invocation. This can be overwritten when
          # invoking it.
          #
          #   arguments %w(app_name --skip-active-record)
          def arguments(array)
            self.default_arguments = array
          end

          # Sets the destination of generator files:
          #
          #   destination File.expand_path("../tmp", __dir__)
          def destination(path)
            self.destination_root = path
          end
        end

        # Runs the generator configured for this class. The first argument is an array like
        # command line arguments:
        #
        #   class AppGeneratorTest < Rails::Generators::TestCase
        #     tests AppGenerator
        #     destination File.expand_path("../tmp", __dir__)
        #     setup :prepare_destination
        #
        #     test "database.yml is not created when skipping Active Record" do
        #       run_generator %w(myapp --skip-active-record)
        #       assert_no_file "config/database.yml"
        #     end
        #   end
        #
        # You can provide a configuration hash as second argument. This method returns the output
        # printed by the generator.
        def run_generator(args = default_arguments, config = {})
          args += ["--skip-bundle"] unless args.include?("--no-skip-bundle") || args.include?("--dev")
          args += ["--skip-bootsnap"] unless args.include?("--no-skip-bootsnap") || args.include?("--skip-bootsnap")

          if ENV["RAILS_LOG_TO_STDOUT"] == "true"
            generator_class.start(args, config.reverse_merge(destination_root: destination_root))
          else
            capture(:stdout) do
              generator_class.start(args, config.reverse_merge(destination_root: destination_root))
            end
          end
        end

        # Instantiate the generator.
        def generator(args = default_arguments, options = {}, config = {})
          @generator ||= generator_class.new(args, options, config.reverse_merge(destination_root: destination_root))
        end

        # Create a Rails::Generators::GeneratedAttribute by supplying the
        # attribute type and, optionally, the attribute name:
        #
        #   create_generated_attribute(:string, "name")
        def create_generated_attribute(attribute_type, name = "test", index = nil)
          Rails::Generators::GeneratedAttribute.parse([name, attribute_type, index].compact.join(":"))
        end

        private
          def destination_root_is_set?
            raise "You need to configure your Rails::Generators::TestCase destination root." unless destination_root
          end

          def ensure_current_path
            cd current_path
          end

          # Clears all files and directories in destination.
          def prepare_destination # :doc:
            rm_rf(destination_root)
            mkdir_p(destination_root)
          end

          def migration_file_name(relative)
            absolute = File.expand_path(relative, destination_root)
            dirname, file_name = File.dirname(absolute), File.basename(absolute).delete_suffix(".rb")
            Dir.glob("#{dirname}/[0-9]*_*.rb").grep(/\d+_#{file_name}.rb$/).first
          end
      end
    end
  end
end
