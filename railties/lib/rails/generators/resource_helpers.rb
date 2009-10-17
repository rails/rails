require 'rails/generators/active_model'

module Rails
  module Generators
    # Deal with controller names on scaffold and add some helpers to deal with
    # ActiveModel.
    #
    module ResourceHelpers
      def self.included(base) #:nodoc:
        base.send :attr_reader, :controller_name, :controller_class_name, :controller_file_name,
                                :controller_class_path, :controller_file_path

        base.send :class_option, :force_plural, :type => :boolean, :desc => "Forces the use of a plural ModelName"
      end

      # Set controller variables on initialization.
      #
      def initialize(*args) #:nodoc:
        super

        if name == name.pluralize && !options[:force_plural]
          say "Plural version of the model detected, using singularized version. Override with --force-plural."
          name.replace name.singularize
          assign_names!(self.name)
        end

        @controller_name = name.pluralize

        base_name, @controller_class_path, @controller_file_path, class_nesting, class_nesting_depth = extract_modules(@controller_name)
        class_name_without_nesting, @controller_file_name, controller_plural_name = inflect_names(base_name)

        @controller_class_name = if class_nesting.empty?
          class_name_without_nesting
        else
          "#{class_nesting}::#{class_name_without_nesting}"
        end
      end

      protected

        # Loads the ORM::Generators::ActiveModel class. This class is responsable
        # to tell scaffold entities how to generate an specific method for the
        # ORM. Check Rails::Generators::ActiveModel for more information.
        #
        def orm_class
          @orm_class ||= begin
            # Raise an error if the class_option :orm was not defined.
            unless self.class.class_options[:orm]
              raise "You need to have :orm as class option to invoke orm_class and orm_instance"
            end

            begin
              "#{options[:orm].to_s.classify}::Generators::ActiveModel".constantize
            rescue NameError => e
              Rails::Generators::ActiveModel
            end
          end
        end

        # Initialize ORM::Generators::ActiveModel to access instance methods.
        #
        def orm_instance(name=file_name)
          @orm_instance ||= @orm_class.new(name)
        end
    end
  end
end
