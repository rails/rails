require 'generators/generators_test_helper'
require 'rails/generators/rails/assets/assets_generator'

# FOXME: Silence the 'Could not find task "using_coffee?"' message in tests due to the public stub
class AssetsGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(posts)

  def test_vanilla_assets
    run_generator
    assert_file "app/assets/javascripts/posts.js"
    assert_file "app/assets/stylesheets/posts.css"
  end

  def test_skipping_assets
    content = run_generator ["posts", "--skip-assets"]
    assert_no_file "app/assets/javascripts/posts.js"
    assert_no_file "app/assets/stylesheets/posts.css"
  end

  def test_coffee_javascript
    self.generator_class.any_instance.stubs(:using_coffee?).returns(true)
    run_generator
    assert_file "app/assets/javascripts/posts.js.coffee"
  end

  def test_sass_stylesheet
    self.generator_class.any_instance.stubs(:using_sass?).returns(true)
    run_generator
    assert_file "app/assets/stylesheets/posts.css.scss"
  end
end
