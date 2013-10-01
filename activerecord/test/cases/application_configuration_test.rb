require 'cases/helper'

module SomeNamespace
  class ApplicationRecord < ::ApplicationRecord
    configs_from(SomeNamespace)
  end

  class SomeModel < ApplicationRecord
  end
end

class AnotherModel < ApplicationRecord
end

class ApplicationConfigurationTest < ActiveRecord::TestCase
  def test_base_application_record
    assert_equal ApplicationRecord, ActiveRecord::Base.application_record
  end

  def test_application_record_method_on_namespace
    assert_equal SomeNamespace::ApplicationRecord, SomeNamespace::ApplicationRecord.application_record
    assert_equal ApplicationRecord, ApplicationRecord.application_record
    assert_nothing_raised do
      assert_equal SomeNamespace::ApplicationRecord, SomeNamespace::ApplicationRecord.application_record('some_object')
      assert_equal ApplicationRecord, ApplicationRecord.application_record('some_object')
    end
  end

  def test_application_record_method_on_model
    assert_equal SomeNamespace::ApplicationRecord, SomeNamespace::SomeModel.application_record
    assert_equal ApplicationRecord, AnotherModel.application_record

    assert_nothing_raised do
      assert_equal SomeNamespace::ApplicationRecord, SomeNamespace::SomeModel.application_record('another_object')
      assert_equal ApplicationRecord, AnotherModel.application_record('another_object')
    end
  end

  def test_application_record_method_on_module
    assert_equal SomeNamespace::ApplicationRecord, SomeNamespace.application_record
    assert_nothing_raised do
      assert_equal SomeNamespace::ApplicationRecord, SomeNamespace.application_record('one_more_object')
    end
  end

  def test_arguments_passed_into_application_record_on_ar_base
    assert_equal SomeNamespace::ApplicationRecord, ActiveRecord::Base.application_record(SomeNamespace)
    assert_equal SomeNamespace::ApplicationRecord, ActiveRecord::Base.application_record(SomeNamespace::SomeModel)
    assert_equal SomeNamespace::ApplicationRecord, ActiveRecord::Base.application_record(SomeNamespace::ApplicationRecord)

    assert_equal ApplicationRecord, ActiveRecord::Base.application_record(AnotherModel)
    assert_equal ApplicationRecord, ActiveRecord::Base.application_record(ApplicationRecord)
  end
end
