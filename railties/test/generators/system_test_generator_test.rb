# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/system_test/system_test_generator"

class SystemTestGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(user)

  def test_system_test_skeleton_is_created
    run_generator
    assert_file "test/system/users_test.rb", /class UsersTest < ApplicationSystemTestCase/
  end

  def test_namespaced_system_test_skeleton_is_created
    run_generator %w(admin/user)
    assert_file "test/system/admin/users_test.rb", /class Admin::UsersTest < ApplicationSystemTestCase/
  end

  def test_test_name_is_pluralized
    run_generator %w(user)

    assert_no_file "test/system/user_test.rb"
    assert_file "test/system/users_test.rb"
  end

  def test_test_suffix_is_not_duplicated
    run_generator %w(users_test)

    assert_no_file "test/system/users_test_test.rb"
    assert_file "test/system/users_test.rb"
  end
end
