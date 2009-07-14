require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/observer/observer_generator'

class ObserverGeneratorTest < GeneratorsTestCase

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
    assert_file "test/unit/account_observer_test.rb", /class AccountObserverTest < ActiveSupport::TestCase/
  end

  def test_logs_if_the_test_framework_cannot_be_found
    content = run_generator ["account", "--test-framework=rspec"]
    assert_match /rspec \[not found\]/, content
  end

  protected

    def run_generator(args=["account"])
      silence(:stdout) { Rails::Generators::ObserverGenerator.start args, :destination_root => destination_root }
    end

end
