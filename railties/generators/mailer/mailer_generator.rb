require 'rails_generator'

class MailerGenerator < Rails::Generator::Base
  attr_reader :actions

  def generate
    @actions = args

    # Mailer class and unit test.
    template "mailer.rb", "app/models/#{file_name}.rb"
    template "unit_test.rb", "test/unit/#{file_name}_test.rb"

    # Test fixtures directory.
    FileUtils.mkdir_p "test/fixtures/#{table_name}"

    # View template and fixture for each action.
    args.each do |action|
      template "view.rhtml", "app/views/#{file_name}/#{action}.rhtml", binding
      template "fixture.rhtml", "test/fixtures/#{table_name}/#{action}", binding
    end
  end
end
