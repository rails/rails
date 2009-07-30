require 'generators/rails/model/model_generator'

module Rails
  module Generators
    class ResourceGenerator < ModelGenerator #metagenerator
      hook_for :resource_controller, :required => true do |base, controller|
        base.invoke controller, [ base.name.pluralize, base.options[:actions] ]
      end

      class_option :actions, :type => :array, :banner => "ACTION ACTION", :default => [],
                             :desc => "Actions for the resource controller"

      class_option :singleton,    :type => :boolean, :desc => "Supply to create a singleton controller"
      class_option :force_plural, :type => :boolean, :desc => "Forces the use of a plural ModelName"

      def initialize(*args)
        super
        if name == name.pluralize && !options[:force_plural]
          say "Plural version of the model detected, using singularized version. Override with --force-plural."
          name.replace name.singularize
        end
      end

      def add_resource_route
        route "map.resource#{:s unless options[:singleton]} :#{pluralize?(file_name)}"
      end

      protected

        def pluralize?(name)
          if options[:singleton]
            name
          else
            name.pluralize
          end
        end

    end
  end
end
