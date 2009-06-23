module Rails::Generators
  class MetalGenerator < Base
    argument :file_name, :type => :string

    def create_file
      template "metal.rb", "app/metal/#{file_name}.rb"
    end

    protected

      def class_name
        file_name.classify
      end
  end
end
