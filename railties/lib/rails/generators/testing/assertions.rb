require 'shellwords'

module Rails
  module Generators
    module Testing
      module Assertions
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
          assert File.exist?(absolute), "Expected file #{relative.inspect} to exist, but does not"

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
          assert !File.exist?(absolute), "Expected file #{relative.inspect} to not exist, but does"
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
      end
    end
  end
end
