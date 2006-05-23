class ObserverGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions class_path, "#{class_name}Observer", "#{class_name}ObserverTest"

      # Observer, and test directories.
      m.directory File.join('app/models', class_path)
      m.directory File.join('test/unit', class_path)

      # Observer class and unit test fixtures.
      m.template 'observer.rb',   File.join('app/models', class_path, "#{file_name}_observer.rb")
      m.template 'unit_test.rb',  File.join('test/unit', class_path, "#{file_name}_observer_test.rb")
    end
  end
end
