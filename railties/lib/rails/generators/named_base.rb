require 'rails/generators/base'
require 'rails/generators/generated_attribute'

module Rails
  module Generators
    class NamedBase < Base
      argument :name, :type => :string

      attr_reader :class_name, :singular_name, :plural_name, :table_name,
                  :class_path, :file_path, :class_nesting_depth

      alias :file_name :singular_name

      def initialize(*args) #:nodoc:
        super
        assign_names!(self.name)
        parse_attributes! if respond_to?(:attributes)
      end

      protected

        def assign_names!(given_name) #:nodoc:
          base_name, @class_path, @file_path, class_nesting, @class_nesting_depth = extract_modules(given_name)
          class_name_without_nesting, @singular_name, @plural_name = inflect_names(base_name)

          @table_name = if pluralize_table_names?
            plural_name
          else
            singular_name
          end

          if class_nesting.empty?
            @class_name = class_name_without_nesting
          else
            @table_name = class_nesting.underscore << "_" << @table_name
            @class_name = "#{class_nesting}::#{class_name_without_nesting}"
          end

          @table_name.gsub!('/', '_')
        end

        # Convert attributes hash into an array with GeneratedAttribute objects.
        #
        def parse_attributes! #:nodoc:
          self.attributes = (attributes || []).map do |key_value|
            name, type = key_value.split(':')
            Rails::Generators::GeneratedAttribute.new(name, type)
          end
        end

        # Extract modules from filesystem-style or ruby-style path. Both
        # good/fun/stuff and Good::Fun::Stuff produce the same results.
        #
        def extract_modules(name) #:nodoc:
          modules = name.include?('/') ? name.split('/') : name.split('::')
          name    = modules.pop
          path    = modules.map { |m| m.underscore }

          file_path = (path + [name.underscore]).join('/')
          nesting   = modules.map { |m| m.camelize }.join('::')

          [name, path, file_path, nesting, modules.size]
        end

        # Receives name and return camelized, underscored and pluralized names.
        #
        def inflect_names(name) #:nodoc:
          camel  = name.camelize
          under  = camel.underscore
          plural = under.pluralize
          [camel, under, plural]
        end

        def pluralize_table_names?
          !defined?(ActiveRecord::Base) || ActiveRecord::Base.pluralize_table_names
        end

        # Add a class collisions name to be checked on class initialization. You
        # can supply a hash with a :prefix or :suffix to be tested.
        #
        # ==== Examples
        #
        #   check_class_collision :suffix => "Observer"
        #
        # If the generator is invoked with class name Admin, it will check for
        # the presence of "AdminObserver".
        #
        def self.check_class_collision(options={})
          define_method :check_class_collision do
            name = if self.respond_to?(:controller_class_name) # for ScaffoldBase
              controller_class_name
            else
              class_name
            end

            class_collisions "#{options[:prefix]}#{name}#{options[:suffix]}"
          end
        end
    end
  end
end
