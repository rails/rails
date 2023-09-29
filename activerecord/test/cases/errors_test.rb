# frozen_string_literal: true

require "cases/helper"

class ErrorsTest < ActiveRecord::TestCase
  def test_can_be_instantiated_with_no_args
    base = ActiveRecord::ActiveRecordError
    error_classes = ObjectSpace.each_object(Class).select { |klass| klass < base }

    (error_classes - [ActiveRecord::AmbiguousSourceReflectionForThroughAssociation]).each do |error_class|
      error_class.new.inspect
    rescue ArgumentError
      raise "Instance of #{error_class} can't be initialized with no arguments"
    end
  end
end
