require 'rails_generator'

class ModelGenerator < Rails::Generator::Base
  def generate
    # Model class, unit test, and fixtures.
    template "model.rb", "app/models/#{file_name}.rb"
    template "unit_test.rb", "test/unit/#{file_name}_test.rb"
    template "fixtures.yml", "test/fixtures/#{table_name}.yml"
  end
end
