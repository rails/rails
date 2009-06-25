module Rails
  module Generators
    class ObserverGenerator < NamedBase
      def check_class_collision
        class_collisions "#{class_name}Observer"
      end

      def create_observer_file
        template 'observer.rb', File.join('app/models', class_path, "#{file_name}_observer.rb")
      end

      invoke_for :test_framework
    end
  end
end
