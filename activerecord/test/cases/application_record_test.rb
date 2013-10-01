require 'cases/helper'
require 'models/topic'

class ModelBaseInherited < ActiveRecord::Base
  class << self
    # Use the Man table
    def table_name
      "men"
    end

    def reset_configs
      self.table_name_prefix = ""
      self.table_name_suffix = ""
    end
  end
end

class ModelAppRecordInherited < ApplicationRecord
end

class ModelDoubleInherited < ModelAppRecordInherited
end

class ApplicationRecordTest < ActiveRecord::TestCase
  fixtures :topics

  def test_changing_prefix_on_ar_base
    prefix = 'my_prefix'
    ActiveRecord::Base.table_name_prefix = prefix
    assert_equal prefix, ModelBaseInherited.table_name_prefix
    assert_equal prefix, ModelAppRecordInherited.table_name_prefix
    ActiveRecord::Base.table_name_prefix = ""
  end

  def test_changing_prefix_on_ar_base_inherited_model
    prefix = 'my_prefix'
    new_prefix = 'new_prefix'
    ActiveRecord::Base.table_name_prefix = prefix
    ModelBaseInherited.table_name_prefix = new_prefix

    assert_equal new_prefix, ModelBaseInherited.table_name_prefix
    assert_equal prefix, ActiveRecord::Base.table_name_prefix
    ActiveRecord::Base.table_name_prefix = ""
  end

  def test_changing_prefix_on_application_record_inherited_model
    prefix = 'my_prefix'
    new_prefix = 'new_prefix'
    ActiveRecord::Base.table_name_prefix = prefix
    Topic.table_name_prefix = new_prefix

    assert_equal new_prefix, Topic.table_name_prefix
    assert_equal prefix, ActiveRecord::Base.table_name_prefix
    ActiveRecord::Base.table_name_prefix = ""
    Topic.table_name_prefix = ""
  end

  def test_double_inheritence_rules
    top_suffix = ActiveRecord::Base.table_name_suffix
    new_suffix = 'some_new_suffix'
    newest_suffix = 'an_even_newer_suffix'

    ModelAppRecordInherited.table_name_suffix = new_suffix
    assert_equal top_suffix, ActiveRecord::Base.table_name_suffix
    assert_equal new_suffix, ModelAppRecordInherited.table_name_suffix
    assert_equal new_suffix, ModelDoubleInherited.table_name_suffix

    ModelDoubleInherited.table_name_suffix = newest_suffix
    assert_equal top_suffix, ActiveRecord::Base.table_name_suffix
    assert_equal new_suffix, ModelAppRecordInherited.table_name_suffix
    assert_equal newest_suffix, ModelDoubleInherited.table_name_suffix
  end

  def test_creating_new_record_from_base_inherited
    ModelBaseInherited.reset_configs

    assert_nothing_raised do
      ModelBaseInherited.new
    end
  end

  def test_persisting_new_record_from_base_inherited
    ModelBaseInherited.reset_configs

    man = ModelBaseInherited.new
    man.name = 'John Wang'
    assert_nothing_raised { man.save }

    assert_equal man.id, ModelBaseInherited.find_by_name('John Wang').id
  end
end

class MultipleApplicationRecordTest < ActiveRecord::TestCase
  module FirstNamespace
    class ApplicationRecord < ::ApplicationRecord
    end

    class SomeModel < ApplicationRecord
    end
  end

  module SecondNamespace
    class ApplicationRecord < ::ApplicationRecord
    end

    class SomeModel < ApplicationRecord
    end
  end

  def test_changing_config_in_namespaces_are_isolated
    FirstNamespace::SomeModel.pluralize_table_names = false
    SecondNamespace::SomeModel.pluralize_table_names = true

    assert !FirstNamespace::SomeModel.pluralize_table_names
    assert SecondNamespace::SomeModel.pluralize_table_names

    FirstNamespace::SomeModel.pluralize_table_names = true
  end

  def test_changing_config_on_models_isolated_across_namespaces
    format = :number
    ApplicationRecord.cache_timestamp_format = format
    assert_equal format, FirstNamespace::SomeModel.cache_timestamp_format
    assert_equal format, SecondNamespace::SomeModel.cache_timestamp_format

    new_format = :long
    FirstNamespace::SomeModel.cache_timestamp_format = new_format
    assert_equal format, ApplicationRecord.cache_timestamp_format
    assert_equal new_format, FirstNamespace::SomeModel.cache_timestamp_format
    assert_equal format, SecondNamespace::SomeModel.cache_timestamp_format
    ApplicationRecord.cache_timestamp_format = :nsec
  end

  def test_changing_module_application_record_does_not_propogate
    original_prefix = ApplicationRecord.table_name_prefix
    first_prefix = 'first_prefix'
    second_prefix = 'second_prefix'

    FirstNamespace::ApplicationRecord.table_name_prefix = first_prefix
    SecondNamespace::ApplicationRecord.table_name_prefix = second_prefix

    assert_equal first_prefix, FirstNamespace::ApplicationRecord.table_name_prefix
    assert_equal second_prefix, SecondNamespace::ApplicationRecord.table_name_prefix
    assert_equal first_prefix, FirstNamespace::SomeModel.table_name_prefix
    assert_equal second_prefix, SecondNamespace::SomeModel.table_name_prefix
    assert_equal original_prefix, ApplicationRecord.table_name_prefix
  end

  def test_changing_config_on_model_does_not_move_up_ancestor_chain
    base_scopes = ActiveRecord::Base.default_scopes
    app_record_scopes = ApplicationRecord.default_scopes
    first_namespace_scopes = FirstNamespace::ApplicationRecord.default_scopes
    second_namespace_scopes = SecondNamespace::ApplicationRecord.default_scopes
    new_scopes = [ proc {} ]

    FirstNamespace::SomeModel.default_scopes = new_scopes

    assert_equal new_scopes, FirstNamespace::SomeModel.default_scopes
    assert_equal base_scopes, ActiveRecord::Base.default_scopes
    assert_equal app_record_scopes, ApplicationRecord.default_scopes
    assert_equal first_namespace_scopes, FirstNamespace::ApplicationRecord.default_scopes
    assert_equal second_namespace_scopes, SecondNamespace::ApplicationRecord.default_scopes
  end
end
