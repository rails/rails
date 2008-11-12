class PluginGenerator < Rails::Generator::NamedBase
  attr_reader :plugin_path

  def initialize(runtime_args, runtime_options = {})
    @with_generator = runtime_args.delete("--with-generator")
    super
    @plugin_path = "vendor/plugins/#{file_name}"
  end

  def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions class_name

      m.directory "#{plugin_path}/lib"
      m.directory "#{plugin_path}/tasks"
      m.directory "#{plugin_path}/test"

      m.template 'README',         "#{plugin_path}/README"
      m.template 'MIT-LICENSE',    "#{plugin_path}/MIT-LICENSE"
      m.template 'Rakefile',       "#{plugin_path}/Rakefile"
      m.template 'init.rb',        "#{plugin_path}/init.rb"
      m.template 'install.rb',     "#{plugin_path}/install.rb"
      m.template 'uninstall.rb',   "#{plugin_path}/uninstall.rb"
      m.template 'plugin.rb',      "#{plugin_path}/lib/#{file_name}.rb"
      m.template 'tasks.rake',     "#{plugin_path}/tasks/#{file_name}_tasks.rake"
      m.template 'unit_test.rb',   "#{plugin_path}/test/#{file_name}_test.rb"
      m.template 'test_helper.rb', "#{plugin_path}/test/test_helper.rb"
      if @with_generator
        m.directory "#{plugin_path}/generators"
        m.directory "#{plugin_path}/generators/#{file_name}"
        m.directory "#{plugin_path}/generators/#{file_name}/templates"

        m.template 'generator.rb', "#{plugin_path}/generators/#{file_name}/#{file_name}_generator.rb"
        m.template 'USAGE',        "#{plugin_path}/generators/#{file_name}/USAGE"
      end
    end
  end
end
