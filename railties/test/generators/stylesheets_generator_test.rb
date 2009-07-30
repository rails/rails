require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/stylesheets/stylesheets_generator'

class StylesheetsGeneratorTest < GeneratorsTestCase

  def test_copy_stylesheets
    run_generator
    assert_file "public/stylesheets/scaffold.css"
  end

  def test_stylesheets_are_not_deleted_on_revoke
    run_generator
    run_generator :behavior => :revoke
    assert_file "public/stylesheets/scaffold.css"
  end

  protected

    def run_generator(config={})
      silence(:stdout) { Rails::Generators::StylesheetsGenerator.start [], config.merge(:destination_root => destination_root) }
    end

end
