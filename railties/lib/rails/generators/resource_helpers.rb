require 'rails/generators/active_model'

module Rails
  module Generators
    # Deal with controller names on scaffold and add some helpers to deal with
    # ActiveModel.
    #
    module ResourceHelpers
      mattr_accessor :skip_warn

      def self.included(base) #:nodoc:
        base.class_option :force_plural, :type => :boolean, :desc => "Forces the use of a plural ModelName"
      end

      # Set controller variables on initialization.
      #
      def initialize(*args) #:nodoc:
        super

        if name == name.pluralize && name.singularize != name.pluralize && !options[:force_plural]
          unless ResourceHelpers.skip_warn
            say "Plural version of the model detected, using singularized version. Override with --force-plural."
            ResourceHelpers.skip_warn = true
          end
          name.replace name.singularize
          assign_names!(name)
        end

        @controller_name = name.pluralize
      end

      protected

        attr_reader :controller_name

        def controller_class_path
          class_path
        end

        def controller_file_name
          @controller_file_name ||= file_name.pluralize
        end

        def controller_file_path
          @controller_file_path ||= (controller_class_path + [controller_file_name]).join('/')
        end

        def controller_class_name
          (controller_class_path + [controller_file_name]).map!{ |m| m.camelize }.join('::')
        end

        def controller_i18n_scope
          @controller_i18n_scope ||= controller_file_path.gsub('/', '.')
        end

        # Loads the ORM::Generators::ActiveModel class. This class is responsible
        # to tell scaffold entities how to generate an specific method for the
        # ORM. Check Rails::Generators::ActiveModel for more information.
        def orm_class
          @orm_class ||= begin
            # Raise an error if the class_option :orm was not defined.
            unless self.class.class_options[:orm]
              raise "You need to have :orm as class option to invoke orm_class and orm_instance"
            end

            begin
              "#{options[:orm].to_s.camelize}::Generators::ActiveModel".constantize
            rescue NameError
              Rails::Generators::ActiveModel
            end
          end
        end

        # Initialize ORM::Generators::ActiveModel to access instance methods.
        def orm_instance(name=singular_table_name)
          @orm_instance ||= orm_class.new(name)
        end
    end
  end
end
