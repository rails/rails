class PerformanceTestGenerator < Rails::Generator::NamedBase
  default_options :skip_migration => false

  def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions class_path, class_name, "#{class_name}Test"

      # performance test directory
      m.directory File.join('test/performance', class_path)

      # performance test stub
      m.template 'performance_test.rb', File.join('test/performance', class_path, "#{file_name}_test.rb")
    end
  end
end
