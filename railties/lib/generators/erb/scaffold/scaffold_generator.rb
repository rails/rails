require 'generators/erb'

module Erb
  module Generators
    class ScaffoldGenerator < Base
      include Rails::Generators::ControllerNamedBase

      argument :attributes, :type => :hash, :default => {}, :banner => "field:type field:type"
      class_option :singleton, :type => :boolean, :desc => "Supply to skip index action"

      # TODO Spec me
      def copy_index_file
        return if options[:singleton]
        copy_view :index
      end

      def copy_edit_file
        copy_view :edit
      end

      def copy_show_file
        copy_view :show
      end

      def copy_new_file
        copy_view :new
      end

      # TODO invoke_if?
      def copy_layout_file
        template "layout.html.erb",
                 File.join("app/views/layouts", controller_class_path, "#{controller_file_name}.html.erb")
      end

      protected

        def copy_view(view)
          template "#{view}.html.erb", File.join("app/views", controller_file_path, "#{view}.html.erb")
        end

    end
  end
end
