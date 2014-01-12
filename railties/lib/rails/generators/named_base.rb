require 'active_support/core_ext/module/introspection'
require 'rails/generators/base'
require 'rails/generators/generated_attribute'

module Rails
  module Generators
    class NamedBase < Base
      argument :name, type: :string
      class_option :skip_namespace, type: :boolean, default: false,
                                    desc: "Skip namespace (affects only isolated applications)"

      def initialize(args, *options) #:nodoc:
        @inside_template = nil
        # Unfreeze name in case it's given as a frozen string
        args[0] = args[0].dup if args[0].is_a?(String) && args[0].frozen?
        super
        assign_names!(self.name)
        parse_attributes! if respond_to?(:attributes)
      end

      # Defines the template that would be used for the migration file.
      # The arguments include the source template file, the migration filename etc.
      no_tasks do
        def template(source, *args, &block)
          inside_template do
            super
          end
        end
      end

      protected
        attr_reader :file_name
        alias :singular_name :file_name

        # Wrap block with namespace of current application
        # if namespace exists and is not skipped
        def module_namespacing(&block)
          content = capture(&block)
          content = wrap_with_namespace(content) if namespaced?
          concat(content)
        end

        def indent(content, multiplier = 2)
          spaces = " " * multiplier
          content.each_line.map {|line| line.blank? ? line : "#{spaces}#{line}" }.join
        end

        def wrap_with_namespace(content)
          content = indent(content).chomp
          "module #{namespace.name}\n#{content}\nend\n"
        end

        def inside_template
          @inside_template = true
          yield
        ensure
          @inside_template = false
        end

        def inside_template?
          @inside_template
        end

        def namespace
          Rails::Generators.namespace
        end

        def namespaced?
          !options[:skip_namespace] && namespace
        end

        def file_path
          @file_path ||= (class_path + [file_name]).join('/')
        end

        def class_path
          inside_template? || !namespaced? ? regular_class_path : namespaced_class_path
        end

        def regular_class_path
          @class_path
        end

        def namespaced_file_path
          @namespaced_file_path ||= namespaced_class_path.join("/")
        end

        def namespaced_class_path
          @namespaced_class_path ||= [namespaced_path] + @class_path
        end

        def namespaced_path
          @namespaced_path ||= namespace.name.split("::").first.underscore
        end

        def class_name
          (class_path + [file_name]).map!{ |m| m.camelize }.join('::')
        end

        def human_name
          @human_name ||= singular_name.humanize
        end

        def plural_name
          @plural_name ||= singular_name.pluralize
        end

        def i18n_scope
          @i18n_scope ||= file_path.tr('/', '.')
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
          @singular_table_name ||= (pluralize_table_names? ? table_name.singularize : table_name)
        end

        def plural_table_name
          @plural_table_name ||= (pluralize_table_names? ? table_name : table_name.pluralize)
        end

        def plural_file_name
          @plural_file_name ||= file_name.pluralize
        end

        def route_url
          @route_url ||= class_path.collect {|dname| "/" + dname }.join + "/" + plural_file_name
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
          self.attributes = (attributes || []).map do |attr|
            Rails::Generators::GeneratedAttribute.parse(attr)
          end
        end

        def attributes_names
          @attributes_names ||= attributes.each_with_object([]) do |a, names|
            names << a.column_name
            names << 'password_confirmation' if a.password_digest?
            names << "#{a.name}_type" if a.polymorphic?
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
        #   check_class_collision suffix: "Decorator"
        #
        # If the generator is invoked with class name Admin, it will check for
        # the presence of "AdminDecorator".
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
