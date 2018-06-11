# frozen_string_literal: true

require "cases/helper"

module SchemaLoadCounter
  extend ActiveSupport::Concern

  module ClassMethods
    attr_accessor :load_schema_calls

    def load_schema!
      self.load_schema_calls ||= 0
      self.load_schema_calls += 1
      super
    end
  end
end

class SchemaLoadingTest < ActiveRecord::TestCase
  def test_basic_model_is_loaded_once
    klass = define_model
    klass.new
    assert_equal 1, klass.load_schema_calls
  end

  def test_model_with_custom_lock_is_loaded_once
    klass = define_model do |c|
      c.table_name = :lock_without_defaults_cust
      c.locking_column = :custom_lock_version
    end
    klass.new
    assert_equal 1, klass.load_schema_calls
  end

  def test_model_with_changed_custom_lock_is_loaded_twice
    klass = define_model do |c|
      c.table_name = :lock_without_defaults_cust
    end
    custom_lock_version = :custom_lock_version
    klass.new
    klass.locking_column = custom_lock_version
    klass.new
    assert_equal 2, klass.load_schema_calls
    assert_equal klass.locking_column, custom_lock_version.to_s
  end

  def test_model_has_lock_version_column_returns_lock_version
    klass = define_model
    assert klass.column_names.include? ActiveRecord::Locking::Optimistic::ClassMethods::DEFAULT_LOCKING_COLUMN
    assert_equal klass.locking_column, ActiveRecord::Locking::Optimistic::ClassMethods::DEFAULT_LOCKING_COLUMN
  end

  def test_return_nil_when_model_have_not_locking_column
    klass = define_model do |c|
      c.table_name = :lions
    end
    assert_nil klass.locking_column
  end

  private

    def define_model
      Class.new(ActiveRecord::Base) do
        include SchemaLoadCounter
        self.table_name = :lock_without_defaults
        yield self if block_given?
      end
    end
end
