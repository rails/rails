require 'generators/generators_test_helper'
require 'rails/generators/rails/stylesheets/stylesheets_generator'

class StylesheetsGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def test_copy_scss_stylesheet
    self.generator_class.any_instance.stubs(:using_sass?).returns(true)
    run_generator
    assert_file "app/assets/stylesheets/scaffold.css.scss"
  end

  def test_copy_css_stylesheet
    run_generator
    assert_file "app/assets/stylesheets/scaffold.css"
  end

  def test_stylesheets_are_not_deleted_on_revoke
    run_generator
    run_generator [], :behavior => :revoke
    assert_file "app/assets/stylesheets/scaffold.css"
  end
end
