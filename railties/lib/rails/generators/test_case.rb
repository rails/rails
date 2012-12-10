require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/core_ext/kernel/reporting'
require 'rails/generators'
require 'fileutils'

module Rails
  module Generators
    # Disable color in output. Easier to debug.
    no_color!

    # This class provides a TestCase for testing generators. To setup, you need
    # just to configure the destination and set which generator is being tested:
    #
    #   class AppGeneratorTest < Rails::Generators::TestCase
    #     tests AppGenerator
    #     destination File.expand_path("../tmp", File.dirname(__FILE__))
    #   end
    #
    # If you want to ensure your destination root is clean before running each test,
    # you can set a setup callback:
    #
    #   class AppGeneratorTest < Rails::Generators::TestCase
    #     tests AppGenerator
    #     destination File.expand_path("../tmp", File.dirname(__FILE__))
    #     setup :prepare_destination
    #   end
    class TestCase < ActiveSupport::TestCase
      include FileUtils

      class_attribute :destination_root, :current_path, :generator_class, :default_arguments

      # Generators frequently change the current path using +FileUtils.cd+.
      # So we need to store the path at file load and revert back to it after each test.
      self.current_path = File.expand_path(Dir.pwd)
      self.default_arguments = []

      def setup # :nodoc:
        destination_root_is_set?
        ensure_current_path
        super
      end

      def teardown # :nodoc:
        ensure_current_path
        super
      end

      # Sets which generator should be tested:
      #
      #   tests AppGenerator
      def self.tests(klass)
        self.generator_class = klass
      end

      # Sets default arguments on generator invocation. This can be overwritten when
      # invoking it.
      #
      #   arguments %w(app_name --skip-active-record)
      def self.arguments(array)
        self.default_arguments = array
      end

      # Sets the destination of generator files:
      #
      #   destination File.expand_path("../tmp", File.dirname(__FILE__))
      def self.destination(path)
        self.destination_root = path
      end

      # Asserts a given file exists. You need to supply an absolute path or a path relative
      # to the configured destination:
      #
      #   assert_file "config/environment.rb"
      #
      # You can also give extra arguments. If the argument is a regexp, it will check if the
      # regular expression matches the given file content. If it's a string, it compares the
      # file with the given string:
      #
      #   assert_file "config/environment.rb", /initialize/
      #
      # Finally, when a block is given, it yields the file content:
      #
      #   assert_file "app/controllers/products_controller.rb" do |controller|
      #     assert_instance_method :index, controller do |index|
      #       assert_match(/Product\.all/, index)
      #     end
      #   end
      def assert_file(relative, *contents)
        absolute = File.expand_path(relative, destination_root)
        assert File.exists?(absolute), "Expected file #{relative.inspect} to exist, but does not"

        read = File.read(absolute) if block_given? || !contents.empty?
        yield read if block_given?

        contents.each do |content|
          case content
            when String
              assert_equal content, read
            when Regexp
              assert_match content, read
          end
        end
      end
      alias :assert_directory :assert_file

      # Asserts a given file does not exist. You need to supply an absolute path or a
      # path relative to the configured destination:
      #
      #   assert_no_file "config/random.rb"
      def assert_no_file(relative)
        absolute = File.expand_path(relative, destination_root)
        assert !File.exists?(absolute), "Expected file #{relative.inspect} to not exist, but does"
      end
      alias :assert_no_directory :assert_no_file

      # Asserts a given migration exists. You need to supply an absolute path or a
      # path relative to the configured destination:
      #
      #   assert_migration "db/migrate/create_products.rb"
      #
      # This method manipulates the given path and tries to find any migration which
      # matches the migration name. For example, the call above is converted to:
      #
      #   assert_file "db/migrate/003_create_products.rb"
      #
      # Consequently, assert_migration accepts the same arguments has assert_file.
      def assert_migration(relative, *contents, &block)
        file_name = migration_file_name(relative)
        assert file_name, "Expected migration #{relative} to exist, but was not found"
        assert_file file_name, *contents, &block
      end

      # Asserts a given migration does not exist. You need to supply an absolute path or a
      # path relative to the configured destination:
      #
      #   assert_no_migration "db/migrate/create_products.rb"
      def assert_no_migration(relative)
        file_name = migration_file_name(relative)
        assert_nil file_name, "Expected migration #{relative} to not exist, but found #{file_name}"
      end

      # Asserts the given class method exists in the given content. This method does not detect
      # class methods inside (class << self), only class methods which starts with "self.".
      # When a block is given, it yields the content of the method.
      #
      #   assert_migration "db/migrate/create_products.rb" do |migration|
      #     assert_class_method :up, migration do |up|
      #       assert_match(/create_table/, up)
      #     end
      #   end
      def assert_class_method(method, content, &block)
        assert_instance_method "self.#{method}", content, &block
      end

      # Asserts the given method exists in the given content. When a block is given,
      # it yields the content of the method.
      #
      #   assert_file "app/controllers/products_controller.rb" do |controller|
      #     assert_instance_method :index, controller do |index|
      #       assert_match(/Product\.all/, index)
      #     end
      #   end
      def assert_instance_method(method, content)
        assert content =~ /(\s+)def #{method}(\(.+\))?(.*?)\n\1end/m, "Expected to have method #{method}"
        yield $3.strip if block_given?
      end
      alias :assert_method :assert_instance_method

      # Asserts the given attribute type gets translated to a field type
      # properly:
      #
      #   assert_field_type :date, :date_select
      def assert_field_type(attribute_type, field_type)
        assert_equal(field_type, create_generated_attribute(attribute_type).field_type)
      end

      # Asserts the given attribute type gets a proper default value:
      #
      #   assert_field_default_value :string, "MyString"
      def assert_field_default_value(attribute_type, value)
        assert_equal(value, create_generated_attribute(attribute_type).default)
      end

      # Runs the generator configured for this class. The first argument is an array like
      # command line arguments:
      #
      #   class AppGeneratorTest < Rails::Generators::TestCase
      #     tests AppGenerator
      #     destination File.expand_path("../tmp", File.dirname(__FILE__))
      #     teardown :cleanup_destination_root
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
        capture(:stdout) { self.generator_class.start(args, config.reverse_merge(destination_root: destination_root)) }
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
    end
  end
end
