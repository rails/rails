require 'rails/generators/rails/model/model_generator'
require 'rails/generators/resource_helpers'

module Rails
  module Generators
    class ResourceGenerator < ModelGenerator #metagenerator
      include ResourceHelpers

      hook_for :resource_controller, :required => true do |base, controller|
        base.invoke controller, [ base.controller_name, base.options[:actions] ]
      end

      class_option :actions, :type => :array, :banner => "ACTION ACTION", :default => [],
                             :desc => "Actions for the resource controller"

      class_option :singleton, :type => :boolean, :desc => "Supply to create a singleton controller"

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
