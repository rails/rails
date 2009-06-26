require 'generators/base'
require 'generators/generated_attribute'

module Rails
  module Generators
    class NamedBase < Base
      argument :name, :type => :string

      attr_reader :class_name, :singular_name, :plural_name, :table_name,
                  :class_path, :file_path, :class_nesting, :class_nesting_depth

      alias :file_name :singular_name

      def initialize(*args)
        super
        assign_names!(self.name)
        parse_attributes! if respond_to?(:attributes)
      end

      protected

        def assign_names!(given_name)
          self.name, @class_path, @file_path, @class_nesting, @class_nesting_depth = extract_modules(given_name)
          @class_name_without_nesting, @singular_name, @plural_name = inflect_names(self.name)

          @table_name = if !defined?(ActiveRecord::Base) || ActiveRecord::Base.pluralize_table_names
            plural_name
          else
            singular_name
          end
          @table_name.gsub! '/', '_'

          if @class_nesting.empty?
            @class_name = @class_name_without_nesting
          else
            @table_name = @class_nesting.underscore << "_" << @table_name
            @class_name = "#{@class_nesting}::#{@class_name_without_nesting}"
          end
        end

        # Convert attributes hash into an array with GeneratedAttribute objects.
        #
        def parse_attributes!
          attributes.map! do |name, type|
            Rails::Generator::GeneratedAttribute.new(name, type)
          end
        end

        # Extract modules from filesystem-style or ruby-style path. Both
        # good/fun/stuff and Good::Fun::Stuff produce the same results.
        #
        def extract_modules(name)
          modules = name.include?('/') ? name.split('/') : name.split('::')
          name    = modules.pop
          path    = modules.map { |m| m.underscore }

          file_path = (path + [name.underscore]).join('/')
          nesting   = modules.map { |m| m.camelize }.join('::')

          [name, path, file_path, nesting, modules.size]
        end

        # Receives name and return camelized, underscored and pluralized names.
        #
        def inflect_names(name)
          camel  = name.camelize
          under  = camel.underscore
          plural = under.pluralize
          [camel, under, plural]
        end

    end
  end
end
