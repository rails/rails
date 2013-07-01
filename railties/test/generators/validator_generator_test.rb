require 'generators/generators_test_helper'
require 'rails/generators/rails/validator/validator_generator'

class ValidatorGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def test_validator
    run_generator ["Email"]
    assert_file "app/validators/email_validator.rb", /ActiveModel::Validator/
    assert_file "test/validators/email_validator_test.rb"
  end

  def test_with_each_option
    run_generator ["Email", "--each"]
    assert_file "app/validators/email_validator.rb", /ActiveModel::EachValidator/
    assert_file "test/validators/email_validator_test.rb"
  end

  def test_namespace
    run_generator ["admin/email"]
    assert_file "app/validators/admin/email_validator.rb", /class Admin::EmailValidator/
    assert_file "test/validators/admin/email_validator_test.rb"
  end

  def test_namespace_with_each
    run_generator ["foo/bar", "--each"]
    assert_file "app/validators/foo/bar_validator.rb", /class Foo::BarValidator < ActiveModel::EachValidator/
    assert_file "test/validators/foo/bar_validator_test.rb"
  end
end
