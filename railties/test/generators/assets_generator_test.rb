# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/assets/assets_generator"

class AssetsGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(posts)

  def test_assets
    run_generator
    assert_file "app/assets/stylesheets/posts.css"
  end

  def test_skipping_assets
    run_generator ["posts", "--no-stylesheets"]
    assert_no_file "app/assets/stylesheets/posts.css"
  end
end
