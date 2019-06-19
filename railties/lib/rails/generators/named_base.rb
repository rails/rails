# frozen_string_literal: true

require "rails/generators/base"
require "rails/generators/generated_attribute"

module Rails
  module Generators
    class NamedBase < Base
      argument :name, type: :string

      def initialize(args, *options) #:nodoc:
        @inside_template = nil
        # Unfreeze name in case it's given as a frozen string
        args[0] = args[0].dup if args[0].is_a?(String) && args[0].frozen?
        super
        assign_names!(name)
        parse_attributes! if respond_to?(:attributes)
      end

      # Overrides <tt>Thor::Actions#template</tt> so it can tell if
      # a template is currently being created.
      no_tasks do
        def template(source, *args, &block)
          inside_template do
            Rails::Generators.add_generated_file(super)
          end
        end

        def js_template(source, destination)
          template(source + ".js", destination + ".js")
        end
      end

      private
        attr_reader :file_name

        # FIXME: We are avoiding to use alias because a bug on thor that make
        # this method public and add it to the task list.
        def singular_name # :doc:
          file_name
        end

        def inside_template # :doc:
          @inside_template = true
          yield
        ensure
          @inside_template = false
        end

        def inside_template? # :doc:
          @inside_template
        end

        def file_path # :doc:
          @file_path ||= (class_path + [file_name]).join("/")
        end

        def class_path # :doc:
          inside_template? || !namespaced? ? regular_class_path : namespaced_class_path
        end

        def regular_class_path # :doc:
          @class_path
        end

        def namespaced_class_path # :doc:
          @namespaced_class_path ||= namespace_dirs + @class_path
        end

        def class_name # :doc:
          (class_path + [file_name]).map!(&:camelize).join("::")
        end

        def human_name # :doc:
          @human_name ||= singular_name.humanize
        end

        def plural_name # :doc:
          @plural_name ||= singular_name.pluralize
        end

        def i18n_scope # :doc:
          @i18n_scope ||= file_path.tr("/", ".")
        end

        def table_name # :doc:
          @table_name ||= begin
            base = pluralize_table_names? ? plural_name : singular_name
            (class_path + [base]).join("_")
          end
        end

        def uncountable? # :doc:
          singular_name == plural_name
        end

        def index_helper # :doc:
          uncountable? ? "#{plural_route_name}_index" : plural_route_name
        end

        def show_helper # :doc:
          "#{singular_route_name}_url(@#{singular_table_name})"
        end

        def edit_helper # :doc:
          "edit_#{show_helper}"
        end

        def new_helper # :doc:
          "new_#{singular_route_name}_url"
        end

        def singular_table_name # :doc:
          @singular_table_name ||= (pluralize_table_names? ? table_name.singularize : table_name)
        end

        def plural_table_name # :doc:
          @plural_table_name ||= (pluralize_table_names? ? table_name : table_name.pluralize)
        end

        def plural_file_name # :doc:
          @plural_file_name ||= file_name.pluralize
        end

        def fixture_file_name # :doc:
          @fixture_file_name ||= (pluralize_table_names? ? plural_file_name : file_name)
        end

        def route_url # :doc:
          @route_url ||= class_path.collect { |dname| "/" + dname }.join + "/" + plural_file_name
        end

        def url_helper_prefix # :doc:
          @url_helper_prefix ||= (class_path + [file_name]).join("_")
        end

        # Tries to retrieve the application name or simply return application.
        def application_name # :doc:
          if defined?(Rails) && Rails.application
            Rails.application.class.name.split("::").first.underscore
          else
            "application"
          end
        end

        def redirect_resource_name # :doc:
          model_resource_name(prefix: "@")
        end

        def model_resource_name(prefix: "") # :doc:
          resource_name = "#{prefix}#{singular_table_name}"
          if options[:model_name]
            "[#{controller_class_path.map { |name| ":" + name }.join(", ")}, #{resource_name}]"
          else
            resource_name
          end
        end

        def singular_route_name # :doc:
          if options[:model_name]
            "#{controller_class_path.join('_')}_#{singular_table_name}"
          else
            singular_table_name
          end
        end

        def plural_route_name # :doc:
          if options[:model_name]
            "#{controller_class_path.join('_')}_#{plural_table_name}"
          else
            plural_table_name
          end
        end

        def assign_names!(name)
          @class_path = name.include?("/") ? name.split("/") : name.split("::")
          @class_path.map!(&:underscore)
          @file_name = @class_path.pop
        end

        # Convert attributes array into GeneratedAttribute objects.
        def parse_attributes!
          self.attributes = (attributes || []).map do |attr|
            Rails::Generators::GeneratedAttribute.parse(attr)
          end
        end

        def attributes_names # :doc:
          @attributes_names ||= attributes.each_with_object([]) do |a, names|
            names << a.column_name
            names << "password_confirmation" if a.password_digest?
            names << "#{a.name}_type" if a.polymorphic?
          end
        end

        def pluralize_table_names? # :doc:
          !defined?(ActiveRecord::Base) || ActiveRecord::Base.pluralize_table_names
        end

        def mountable_engine? # :doc:
          defined?(ENGINE_ROOT) && namespaced?
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
        def self.check_class_collision(options = {}) # :doc:
          define_method :check_class_collision do
            name = if respond_to?(:controller_class_name, true) # for ResourceHelpers
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
