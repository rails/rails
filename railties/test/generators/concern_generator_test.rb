require 'generators/generators_test_helper'
require 'rails/generators/rails/concern/concern_generator'

class ConcernGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(User::Authentication)

  def test_concern_is_created
    run_generator
    assert_file 'app/models/user/authentication.rb' do |content|
      assert_match(/module User::Authentication/, content)
      assert_match(/extend ActiveSupport::Concern/, content)
      assert_match(/included do/, content)
    end
  end

  def test_concern_on_revoke
    concern_path = 'app/models/user/authentication.rb'
    run_generator
    assert_file concern_path
    run_generator ['User::Authentication'], behavior: :revoke
    assert_no_file concern_path
  end
end

class ControllerConcernGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  self.generator_class = Rails::Generators::ConcernGenerator
  arguments %w(admin_controller/localized)

  def test_concern_is_created
    run_generator
    assert_file 'app/controllers/admin_controller/localized.rb' do |content|
      assert_match(/module AdminController::Localized/, content)
      assert_match(/extend ActiveSupport::Concern/, content)
      assert_match(/included do/, content)
    end
  end
end
