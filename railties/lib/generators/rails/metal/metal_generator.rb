module Rails
  module Generators
    class MetalGenerator < NamedBase
      def check_class_collision
        class_collisions class_name
      end

      def create_file
        template "metal.rb", "app/metal/#{file_name}.rb"
      end
    end
  end
end
