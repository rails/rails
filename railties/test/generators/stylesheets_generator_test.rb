require 'generators/generators_test_helper'
require 'rails/generators/rails/stylesheets/stylesheets_generator'

class StylesheetsGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def test_copy_stylesheets
    run_generator
    assert_file "public/stylesheets/scaffold.css"
  end

  def test_stylesheets_are_not_deleted_on_revoke
    run_generator
    run_generator [], :behavior => :revoke
    assert_file "public/stylesheets/scaffold.css"
  end
end
