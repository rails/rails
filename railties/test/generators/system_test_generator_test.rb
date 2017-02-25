require "generators/generators_test_helper"
require "rails/generators/rails/system_test/system_test_generator"

class SystemTestGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(user)

  def test_system_test_skeleton_is_created
    run_generator
    assert_file "test/system/users_test.rb", /class UsersTest < ApplicationSystemTestCase/
  end
end
