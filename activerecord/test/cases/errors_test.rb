# frozen_string_literal: true

require "cases/helper"
require "active_record/errors"

class ErrorsTest < ActiveRecord::TestCase
  def test_can_be_instantiated_with_no_args
    base = ActiveRecord::ActiveRecordError
    error_klasses = ObjectSpace.each_object(Class).select { |klass| klass < base }

    assert_nothing_raised do
      (error_klasses - [ActiveRecord::AmbiguousSourceReflectionForThroughAssociation]).each do |error_klass|
        error_klass.new.inspect
      rescue ArgumentError
        raise "Instance of #{error_klass} can't be initialized with no arguments"
      end
    end
  end

  def test_active_record_immutable_relation_deprecation
    expected_message = "ActiveRecord::ImmutableRelation is deprecated! Use ActiveRecord::UnmodifiableRelation instead"
    assert_deprecated(expected_message, ActiveRecord.deprecator) do
      assert_same ActiveRecord::UnmodifiableRelation, ActiveRecord::ImmutableRelation
    end
  end
end
