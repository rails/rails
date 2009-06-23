module Rails::Generators
  class MetalGenerator < NamedBase
    def create_file
      template "metal.rb", "app/metal/#{file_name}.rb"
    end
  end
end
