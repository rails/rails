class IntegrationTestGenerator < Rails::Generator::NamedBase
  default_options :skip_migration => false

  def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions class_name, "#{class_name}Test"

      # integration test directory
      m.directory File.join('test/integration', class_path)

      # integration test stub
      m.template 'integration_test.rb', File.join('test/integration', class_path, "#{file_name}_test.rb")
    end
  end
end
