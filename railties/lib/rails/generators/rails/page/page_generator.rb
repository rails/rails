# frozen_string_literal: true

module Rails
  module Generators
    class PageGenerator < NamedBase
      class_option :root, type: :boolean, default: false,
        desc: "Add root route"

      def create_controller
        invoke :controller, [name, ["index"]], { skip_routes: true, test_framework: false }
      end

      def add_route
        route "get '#{file_name}', to: '#{file_name}#index'", namespace: regular_class_path
      end

      def add_root_route
        return unless options[:root]
        route "root to: '#{file_name}#index'"
      end

      hook_for :test_framework
    end
  end
end
