# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/poro_model/poro_model_generator"

class PoroModelGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def test_help_shows_invoked_generators_options
    content = run_generator ["--help"]
    assert_match(/Stubs out a new model as Plain Old Ruby Object/, content)
    assert_match(/rails generate poro_model address/, content)
  end

  def test_plural_names_are_singularized
    run_generator ["accounts"]
    assert_file "app/models/account.rb", /class Account/
  end

  def test_model_with_namespace
    run_generator ["Admin::Gallery::Image"]
    assert_file "app/models/admin/gallery/image.rb", /class Admin::Gallery::Image/
  end
end
