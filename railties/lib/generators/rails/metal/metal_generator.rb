module Rails
  module Generators
    class MetalGenerator < NamedBase
      check_class_collision

      def create_metal_file
        template "metal.rb", "app/metal/#{file_name}.rb"
      end
    end
  end
end
