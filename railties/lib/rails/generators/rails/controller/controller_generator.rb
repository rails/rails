module Rails
  module Generators
    class ControllerGenerator < NamedBase # :nodoc:
      argument :actions, type: :array, default: [], banner: "action action"
      class_option :skip_routes, type: :boolean, desc: "Don't add routes to config/routes.rb."
      class_option :helper, type: :boolean
      class_option :assets, type: :boolean

      check_class_collision suffix: "Controller"

      def create_controller_files
        template "controller.rb", File.join("app/controllers", class_path, "#{file_name}_controller.rb")
      end

      def add_routes
        unless options[:skip_routes]
          actions.reverse_each do |action|
            # route prepends two spaces onto the front of the string that is passed, this corrects that.
            route indent(generate_routing_code(action), 2)[2..-1]
          end
        end
      end

      hook_for :template_engine, :test_framework, :helper, :assets

      private

        # This method creates nested route entry for namespaced resources.
        # For eg. rails g controller foo/bar/baz index
        # Will generate -
        # namespace :foo do
        #   namespace :bar do
        #     get 'baz/index'
        #   end
        # end
        def generate_routing_code(action)
          depth = 0
          lines = []

          # Create 'namespace' ladder
          # namespace :foo do
          #   namespace :bar do
          regular_class_path.each do |ns|
            lines << indent("namespace :#{ns} do\n", depth * 2)
            depth += 1
          end

          # Create route
          #     get 'baz/index'
          lines << indent(%{get '#{file_name}/#{action}'\n}, depth * 2)

          # Create `end` ladder
          #   end
          # end
          until depth.zero?
            depth -= 1
            lines << indent("end\n", depth * 2)
          end

          lines.join
        end
    end
  end
end
