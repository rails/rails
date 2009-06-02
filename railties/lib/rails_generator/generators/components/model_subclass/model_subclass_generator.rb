class ModelSubclassGenerator < Rails::Generator::NamedBase
  default_options :skip_unit_test => false

  def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions class_name, "#{class_name}Test"

      # Model and test directories.
      m.directory File.join('app/models', class_path)
      m.directory File.join('test/unit', class_path)

      # Model class and unit test
      m.template 'model.rb',      File.join('app/models', class_path, "#{file_name}.rb"),     :assigns => assigns
      m.template 'unit_test.rb',  File.join('test/unit', class_path, "#{file_name}_test.rb"), :assigns => assigns

    end
  end

  protected
    def banner
      "Usage: #{$0} #{spec.name} Subclass Parent"
    end

    def assigns
      {:parent_class_name => parent_class_name}
    end

    def parent_class_name
      @args.first.try(:camelize) || usage
    end
end
