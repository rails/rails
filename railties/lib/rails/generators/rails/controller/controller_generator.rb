module Rails
  module Generators
    class ControllerGenerator < NamedBase # :nodoc:
      argument :actions, type: :array, default: [], banner: "action action"
      check_class_collision suffix: "Controller"

      def create_controller_files
        template 'controller.rb', File.join('app/controllers', class_path, "#{file_name}_controller.rb")
      end

      def add_routes
        actions.reverse.each do |action|
          route generate_routing_code(action)
        end
      end

      hook_for :template_engine, :test_framework, :helper, :assets

      private

        # This method creates nested route entry for namespaced resources.
        # For eg. rails g controller foo/bar/baz index
        # Will generate -
        # namespace :foo do
        #   namespace :bar do
        #     get "baz/index"
        #   end
        # end
        def generate_routing_code(action)
          depth = class_path.length
          # Create 'namespace' ladder
          # namespace :foo do
          #   namespace :bar do
          namespace_ladder = class_path.each_with_index.map do |ns, i|
            %{#{indent(i)}namespace :#{ns} do\n  }
          end.join

          # Create route
          #     get "baz/index"
          route = %{#{indent(depth)}get "#{file_name}/#{action}"\n}

          # Create `end` ladder
          #   end
          # end
          end_ladder = (1..depth).reverse_each.map do |i|
            "#{indent(i)}end\n"
          end.join

          # Combine the 3 parts to generate complete route entry
          namespace_ladder + route + end_ladder
        end

        def indent(depth)
          " " * depth * 2
        end
    end
  end
end
