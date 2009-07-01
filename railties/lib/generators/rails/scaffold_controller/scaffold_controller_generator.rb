module Rails
  module Generators
    class ScaffoldControllerGenerator < NamedBase
      include ControllerNamedBase

      check_class_collision :suffix => "Controller"

      class_option :orm, :banner => "NAME", :type => :string, :required => true,
                         :desc => "ORM to generate the controller for"

      class_option :singleton, :type => :boolean, :desc => "Supply to create a singleton controller"

      def create_controller_files
        template 'controller.rb', File.join('app/controllers', class_path, "#{controller_file_name}_controller.rb")
      end

      hook_for :template_engine, :test_framework, :as => :scaffold

      # Invoke the helper using the controller (pluralized) name.
      #
      invoke_if :helper do |base, invoked|
        base.invoke invoked, [ base.controller_name ]
      end

      protected

        def orm_class
          @orm_class ||= begin
            action_orm = "#{options[:orm].to_s.classify}::Generators::ActionORM"
            action_orm.constantize
          rescue NameError => e
            raise Error, "Could not load #{action_orm}, skipping controller. Error: #{e.message}."
          end
        end

        def orm_instance
          @orm_instance ||= @orm_class.new(file_name)
        end

    end
  end
end
