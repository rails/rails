class MailerGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions class_name, "#{class_name}Test"

      # Mailer class and unit test.
      m.template "mailer.rb",    "app/models/#{file_name}.rb"
      m.template "unit_test.rb", "test/unit/#{file_name}_test.rb"

      # Views and fixtures directories.
      m.directory "app/views/#{file_name}"
      m.directory "test/fixtures/#{table_name}"

      # View template and fixture for each action.
      actions.each do |action|
        m.template "view.rhtml",
                   "app/views/#{file_name}/#{action}.rhtml",
                   :assigns => { :action => action }
        m.template "fixture.rhtml",
                   "test/fixtures/#{table_name}/#{action}",
                   :assigns => { :action => action }
      end
    end
  end
end
