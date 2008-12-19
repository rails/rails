class MetalGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      m.directory 'app/metal'
      m.template 'metal.rb', File.join('app/metal', "#{file_name}.rb")
    end
  end
end
