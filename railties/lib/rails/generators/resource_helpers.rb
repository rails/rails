# frozen_string_literal: true

require "rails/generators/active_model"
require "rails/generators/model_helpers"

module Rails
  module Generators
    # Deal with controller names on scaffold and add some helpers to deal with
    # ActiveModel.
    module ResourceHelpers # :nodoc:
      def self.included(base) #:nodoc:
        base.include(Rails::Generators::ModelHelpers)
        base.class_option :model_name, type: :string, desc: "ModelName to be used"
      end

      # Set controller variables on initialization.
      def initialize(*args) #:nodoc:
        super
        controller_name = name
        if options[:model_name]
          self.name = options[:model_name]
          assign_names!(name)
        end

        assign_controller_names!(controller_name.pluralize)
      end

      # TODO Change this to private once we've dropped Ruby 2.2 support.
      # Workaround for Ruby 2.2 "private attribute?" warning.
      protected

        attr_reader :controller_name, :controller_file_name

      private

        def controller_class_path
          if options[:model_name]
            @controller_class_path
          else
            class_path
          end
        end

        def assign_controller_names!(name)
          @controller_name = name
          @controller_class_path = name.include?("/") ? name.split("/") : name.split("::")
          @controller_class_path.map!(&:underscore)
          @controller_file_name = @controller_class_path.pop
        end

        def controller_file_path
          @controller_file_path ||= (controller_class_path + [controller_file_name]).join("/")
        end

        def controller_class_name
          (controller_class_path + [controller_file_name]).map!(&:camelize).join("::")
        end

        def controller_i18n_scope
          @controller_i18n_scope ||= controller_file_path.tr("/", ".")
        end

        # Loads the ORM::Generators::ActiveModel class. This class is responsible
        # to tell scaffold entities how to generate a specific method for the
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
        def orm_instance(name = singular_table_name)
          @orm_instance ||= orm_class.new(name)
        end
    end
  end
end
