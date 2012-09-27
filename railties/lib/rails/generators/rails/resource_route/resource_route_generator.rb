module Rails
  module Generators
    class ResourceRouteGenerator < NamedBase
      def add_resource_route
        return if options[:actions].present?
        route_config =  regular_class_path.collect{ |namespace| "namespace :#{namespace} do " }.join(" ")
        route_config << "resources :#{file_name.pluralize}"
        route_config << " end" * regular_class_path.size
        route route_config
      end
    end
  end
end
