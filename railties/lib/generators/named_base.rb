require 'generators/base'
require 'generators/generated_attribute'

module Rails
  module Generators
    class NamedBase < Base
      argument :name, :type => :string

      attr_reader :class_name, :singular_name, :plural_name, :table_name,
                  :class_path, :file_path, :class_nesting, :class_nesting_depth

      alias :file_name :singular_name

      class << self
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
        def check_class_collision(options={})
          @class_collisions = options
        end

        # Returns the class collisions for this class and retreives one from
        # superclass. The from_superclass method used below is from Thor.
        #
        def class_collisions #:nodoc:
          @class_collisions ||= from_superclass(:class_collisions, nil)
        end
      end

      def initialize(*args) #:nodoc:
        super
        assign_names!(self.name)
        parse_attributes! if respond_to?(:attributes)

        if self.class.class_collisions
          value = add_prefix_and_suffix(class_name, self.class.class_collisions) 
          class_collisions(value)
        end
      end

      protected

        def assign_names!(given_name) #:nodoc:
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
        def parse_attributes! #:nodoc:
          attributes.map! do |name, type|
            Rails::Generator::GeneratedAttribute.new(name, type)
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

        # Receives a name and add suffix and prefix values frrm hash.
        #
        def add_prefix_and_suffix(name, hash) #:nodoc:
          "#{hash[:prefix]}#{name}#{hash[:suffix]}"
        end

    end
  end
end
