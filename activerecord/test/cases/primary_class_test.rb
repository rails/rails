# frozen_string_literal: true

require "cases/helper"

class PrimaryClassTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  def teardown
    clean_up_connection_handler
  end

  class PrimaryAppRecord < ActiveRecord::Base
  end

  class AnotherAppRecord < PrimaryAppRecord
    self.abstract_class = true
  end

  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  def test_application_record_is_used_if_no_primary_class_is_set
    Object.const_set(:ApplicationRecord, ApplicationRecord)

    assert_predicate ApplicationRecord, :primary_class?
    assert_predicate ApplicationRecord, :application_record_class?
    assert_predicate ApplicationRecord, :abstract_class?
  ensure
    ActiveRecord.application_record_class = nil
    Object.send(:remove_const, :ApplicationRecord)
  end

  def test_primary_class_and_primary_abstract_class_behavior
    PrimaryClassTest::PrimaryAppRecord.primary_abstract_class

    assert_predicate PrimaryClassTest::PrimaryAppRecord, :primary_class?
    assert_predicate PrimaryClassTest::PrimaryAppRecord, :application_record_class?
    assert_predicate PrimaryClassTest::PrimaryAppRecord, :abstract_class?

    assert_not_predicate AnotherAppRecord, :primary_class?
    assert_not_predicate AnotherAppRecord, :application_record_class?
    assert_predicate AnotherAppRecord, :abstract_class?

    assert_predicate ActiveRecord::Base, :primary_class?
    assert_not_predicate ActiveRecord::Base, :application_record_class?
    assert_not_predicate ActiveRecord::Base, :abstract_class?
  ensure
    ActiveRecord.application_record_class = nil
  end

  def test_primary_abstract_class_cannot_be_reset
    PrimaryClassTest::PrimaryAppRecord.primary_abstract_class

    assert_raises do
      PrimaryClassTest::AnotherAppRecord.primary_abstract_class
    end
  ensure
    ActiveRecord.application_record_class = nil
  end

  def test_primary_abstract_class_is_used_over_application_record_if_set
    PrimaryClassTest::PrimaryAppRecord.primary_abstract_class
    Object.const_set(:ApplicationRecord, ApplicationRecord)

    assert_predicate PrimaryClassTest::PrimaryAppRecord, :primary_class?
    assert_predicate PrimaryClassTest::PrimaryAppRecord, :application_record_class?
    assert_predicate PrimaryClassTest::PrimaryAppRecord, :abstract_class?

    assert_not_predicate ApplicationRecord, :primary_class?
    assert_not_predicate ApplicationRecord, :application_record_class?
    assert_predicate ApplicationRecord, :abstract_class?

    assert_predicate ActiveRecord::Base, :primary_class?
    assert_not_predicate ActiveRecord::Base, :application_record_class?
    assert_not_predicate ActiveRecord::Base, :abstract_class?
  ensure
    ActiveRecord.application_record_class = nil
    Object.send(:remove_const, :ApplicationRecord)
  end

  def test_setting_primary_abstract_class_explicitly_wins_over_application_record_set_implicitly
    Object.const_set(:ApplicationRecord, ApplicationRecord)

    assert_predicate ApplicationRecord, :primary_class?
    assert_predicate ApplicationRecord, :application_record_class?
    assert_predicate ApplicationRecord, :abstract_class?

    PrimaryClassTest::PrimaryAppRecord.primary_abstract_class

    assert_predicate PrimaryClassTest::PrimaryAppRecord, :primary_class?
    assert_predicate PrimaryClassTest::PrimaryAppRecord, :application_record_class?
    assert_predicate PrimaryClassTest::PrimaryAppRecord, :abstract_class?

    assert_not_predicate ApplicationRecord, :primary_class?
    assert_not_predicate ApplicationRecord, :application_record_class?
    assert_predicate ApplicationRecord, :abstract_class?
  ensure
    ActiveRecord.application_record_class = nil
    Object.send(:remove_const, :ApplicationRecord)
  end

  unless in_memory_db?
    def test_application_record_shares_a_connection_with_active_record_by_default
      Object.const_set(:ApplicationRecord, ApplicationRecord)

      ApplicationRecord.connects_to(database: { writing: :arunit, reading: :arunit })

      assert_predicate ApplicationRecord, :primary_class?
      assert_predicate ApplicationRecord, :application_record_class?
      assert_equal ActiveRecord::Base.connection, ApplicationRecord.connection
    ensure
      ActiveRecord.application_record_class = nil
      Object.send(:remove_const, :ApplicationRecord)
      ActiveRecord::Base.establish_connection :arunit
    end

    def test_application_record_shares_a_connection_with_the_primary_abstract_class_if_set
      PrimaryClassTest::PrimaryAppRecord.primary_abstract_class

      PrimaryClassTest::PrimaryAppRecord.connects_to(database: { writing: :arunit, reading: :arunit })

      assert_predicate PrimaryClassTest::PrimaryAppRecord, :primary_class?
      assert_predicate PrimaryClassTest::PrimaryAppRecord, :application_record_class?
      assert_predicate PrimaryClassTest::PrimaryAppRecord, :abstract_class?
      assert_equal ActiveRecord::Base.connection, PrimaryClassTest::PrimaryAppRecord.connection
    ensure
      ActiveRecord.application_record_class = nil
      ActiveRecord::Base.establish_connection :arunit
    end
  end
end
