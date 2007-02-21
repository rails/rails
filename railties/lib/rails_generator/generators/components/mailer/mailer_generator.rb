class MailerGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions class_path, class_name, "#{class_name}Test"

      # Mailer, view, test, and fixture directories.
      m.directory File.join('app/models', class_path)
      m.directory File.join('app/views', file_path)
      m.directory File.join('test/unit', class_path)
      m.directory File.join('test/fixtures', file_path)

      # Mailer class and unit test.
      m.template "mailer.rb",    File.join('app/models',
                                           class_path,
                                           "#{file_name}.rb")
      m.template "unit_test.rb", File.join('test/unit',
                                           class_path,
                                           "#{file_name}_test.rb")

      # View template and fixture for each action.
      actions.each do |action|
        relative_path = File.join(file_path, action)
        view_path     = File.join('app/views', "#{relative_path}.erb")
        fixture_path  = File.join('test/fixtures', relative_path)

        m.template "view.erb", view_path,
                   :assigns => { :action => action, :path => view_path }
        m.template "fixture.erb", fixture_path,
                   :assigns => { :action => action, :path => view_path }
      end
    end
  end
end
