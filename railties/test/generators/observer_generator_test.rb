require 'generators/generators_test_helper'
require 'rails/generators/rails/observer/observer_generator'

class ObserverGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(account)

  def test_invokes_default_orm
    run_generator
    assert_file "app/models/account_observer.rb", /class AccountObserver < ActiveRecord::Observer/
  end

  def test_invokes_default_orm_with_class_path
    run_generator ["admin/account"]
    assert_file "app/models/admin/account_observer.rb", /class Admin::AccountObserver < ActiveRecord::Observer/
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/models/account_observer_test.rb", /class AccountObserverTest < ActiveSupport::TestCase/
  end

  def test_logs_if_the_test_framework_cannot_be_found
    content = run_generator ["account", "--test-framework=rspec"]
    assert_match(/rspec \[not found\]/, content)
  end
end
