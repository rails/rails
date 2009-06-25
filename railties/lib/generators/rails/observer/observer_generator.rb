module Rails
  module Generators
    class ObserverGenerator < NamedBase
      def check_class_collision
        class_collisions "#{class_name}Observer"
      end

      def create_observer_file
        template 'observer.rb', File.join('app/models', class_path, "#{file_name}_observer.rb")
      end

      add_and_invoke_test_framework_option!
    end
  end
end
