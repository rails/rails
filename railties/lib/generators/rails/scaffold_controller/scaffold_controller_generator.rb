module Rails
  module Generators
    class ScaffoldControllerGenerator < NamedBase
      # Add controller methods and ActionORM settings.
      include ScaffoldBase

      check_class_collision :suffix => "Controller"

      class_option :orm, :banner => "NAME", :type => :string, :required => true,
                         :desc => "ORM to generate the controller for"

      class_option :singleton, :type => :boolean, :desc => "Supply to create a singleton controller"

      def create_controller_files
        template 'controller.rb', File.join('app/controllers', class_path, "#{controller_file_name}_controller.rb")
      end

      hook_for :template_engine, :test_framework, :as => :scaffold

      # Invoke the helper using the controller (pluralized) name.
      hook_for :helper, :as => :scaffold do |base, invoked|
        base.invoke invoked, [ base.controller_name ]
      end
    end
  end
end
