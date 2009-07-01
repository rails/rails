require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/stylesheets/stylesheets_generator'

class StylesheetsGeneratorTest < GeneratorsTestCase

  def test_copy_stylesheets
    run_generator
    assert_file "public/stylesheets/scaffold.css"
  end

  protected

    def run_generator(args=[])
      silence(:stdout) { Rails::Generators::StylesheetsGenerator.start args, :root => destination_root }
    end

end
