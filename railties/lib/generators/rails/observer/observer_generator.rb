module Rails
  module Generators
    class ObserverGenerator < NamedBase
      check_class_collision :suffix => "Observer"

      def create_observer_file
        template 'observer.rb', File.join('app/models', class_path, "#{file_name}_observer.rb")
      end

      invoke_for :test_framework
    end
  end
end
