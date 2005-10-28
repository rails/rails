class PluginGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      m.directory File.join('vendor', 'plugins', file_name)
      m.directory File.join('vendor', 'plugins', file_name, 'lib')
      m.directory File.join('vendor', 'plugins', file_name, 'test')
      m.directory File.join('vendor', 'plugins', file_name, 'tasks')

      m.template 'plugin.rb',    File.join('vendor', 'plugins', file_name, 'lib',  "#{file_name}.rb")
      m.template 'unit_test.rb', File.join('vendor', 'plugins', file_name, 'test', "#{file_name}_test.rb")

      m.template 'init.rb',    File.join('vendor', 'plugins', file_name, 'init.rb')
      m.template 'tasks.rake', File.join('vendor', 'plugins', file_name, 'tasks', "#{file_name}_tasks.rake")
      m.template 'README',     File.join('vendor', 'plugins', file_name, 'README')
    end
  end
end
