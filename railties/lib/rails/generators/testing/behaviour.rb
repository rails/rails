require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/core_ext/kernel/reporting'
require 'active_support/concern'
require 'rails/generators'

module Rails
  module Generators
    module Testing
      module Behaviour
        extend ActiveSupport::Concern

        included do
          class_attribute :destination_root, :current_path, :generator_class, :default_arguments

          # Generators frequently change the current path using +FileUtils.cd+.
          # So we need to store the path at file load and revert back to it after each test.
          self.current_path = File.expand_path(Dir.pwd)
          self.default_arguments = []
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
          #   destination File.expand_path("../tmp", File.dirname(__FILE__))
          def destination(path)
            self.destination_root = path
          end
        end

        # Runs the generator configured for this class. The first argument is an array like
        # command line arguments:
        #
        #   class AppGeneratorTest < Rails::Generators::TestCase
        #     tests AppGenerator
        #     destination File.expand_path("../tmp", File.dirname(__FILE__))
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
        def run_generator(args=self.default_arguments, config={})
          capture(:stdout) do
            args += ['--skip-bundle'] unless args.include? '--dev'
            self.generator_class.start(args, config.reverse_merge(destination_root: destination_root))
          end
        end

        # Instantiate the generator.
        def generator(args=self.default_arguments, options={}, config={})
          @generator ||= self.generator_class.new(args, options, config.reverse_merge(destination_root: destination_root))
        end

        # Create a Rails::Generators::GeneratedAttribute by supplying the
        # attribute type and, optionally, the attribute name:
        #
        #   create_generated_attribute(:string, 'name')
        def create_generated_attribute(attribute_type, name = 'test', index = nil)
          Rails::Generators::GeneratedAttribute.parse([name, attribute_type, index].compact.join(':'))
        end

        protected

          def destination_root_is_set? # :nodoc:
            raise "You need to configure your Rails::Generators::TestCase destination root." unless destination_root
          end

          def ensure_current_path # :nodoc:
            cd current_path
          end

          def prepare_destination # :nodoc:
            rm_rf(destination_root)
            mkdir_p(destination_root)
          end

          def migration_file_name(relative) # :nodoc:
            absolute = File.expand_path(relative, destination_root)
            dirname, file_name = File.dirname(absolute), File.basename(absolute).sub(/\.rb$/, '')
            Dir.glob("#{dirname}/[0-9]*_*.rb").grep(/\d+_#{file_name}.rb$/).first
          end

          def capture(stream)
            stream = stream.to_s
            captured_stream = Tempfile.new(stream)
            stream_io = eval("$#{stream}")
            origin_stream = stream_io.dup
            stream_io.reopen(captured_stream)

            yield

            stream_io.rewind
            return captured_stream.read
          ensure
            captured_stream.close
            captured_stream.unlink
            stream_io.reopen(origin_stream)
          end
      end
    end
  end
end
