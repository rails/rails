require 'rails/generators/base'
require 'rails/generators/generated_attribute'

module Rails
  module Generators
    class NamedBase < Base
      argument :name, :type => :string

      def initialize(args, *options) #:nodoc:
        # Unfreeze name in case it's given as a frozen string
        args[0] = args[0].dup if args[0].is_a?(String) && args[0].frozen?
        super
        assign_names!(self.name)
        parse_attributes! if respond_to?(:attributes)
      end

      protected

        attr_reader :class_path, :file_name
        alias :singular_name :file_name

        def file_path
          @file_path ||= (class_path + [file_name]).join('/')
        end

        def class_name
          @class_name ||= (class_path + [file_name]).map!{ |m| m.camelize }.join('::')
        end

        def human_name
          @human_name ||= singular_name.humanize
        end

        def plural_name
          @plural_name ||= singular_name.pluralize
        end

        def i18n_scope
          @i18n_scope ||= file_path.gsub('/', '.')
        end

        def table_name
          @table_name ||= begin
            base = pluralize_table_names? ? plural_name : singular_name
            (class_path + [base]).join('_')
          end
        end

        def uncountable?
          singular_name == plural_name
        end

        def index_helper
          uncountable? ? "#{plural_table_name}_index" : plural_table_name
        end

        def singular_table_name
          @singular_table_name ||= table_name.singularize
        end

        def plural_table_name
          @plural_table_name ||= table_name.pluralize
        end

        def plural_file_name
          @plural_file_name ||= file_name.pluralize
        end

        def route_url
          @route_url ||= class_path.collect{|dname| "/" + dname  }.join('') + "/" + plural_file_name
        end

        # Tries to retrieve the application name or simple return application.
        def application_name
          if defined?(Rails) && Rails.application
            Rails.application.class.name.split('::').first.underscore
          else
            "application"
          end
        end

        def assign_names!(name) #:nodoc:
          @class_path = name.include?('/') ? name.split('/') : name.split('::')
          @class_path.map! { |m| m.underscore }
          @file_name = @class_path.pop
        end

        # Convert attributes array into GeneratedAttribute objects.
        def parse_attributes! #:nodoc:
          self.attributes = (attributes || []).map do |key_value|
            name, type = key_value.split(':')
            Rails::Generators::GeneratedAttribute.new(name, type)
          end
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
