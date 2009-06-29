require 'generators/rails/model/model_generator'

module Rails
  module Generators
    class ResourceGenerator < ModelGenerator
      hook_for :resource_controller do |base, controller|
        base.invoke controller, [ base.name.pluralize, base.options[:actions] ]
      end

      class_option :actions, :type => :array, :default => [], :banner => "ACTION ACTION",
                             :desc => "Actions for the resource controller", :aliases => "-a"

      class_option :singleton, :type => :boolean, :default => false, :aliases => "-i",
                               :desc => "Supply to create a singleton controller"

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
