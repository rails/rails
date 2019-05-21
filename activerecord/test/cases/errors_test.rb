# frozen_string_literal: true

require "cases/helper"

class ErrorsTest < ActiveRecord::TestCase
  def test_can_be_instantiated_with_no_args
    base = ActiveRecord::ActiveRecordError
    error_klasses = ObjectSpace.each_object(Class).select { |klass| klass < base }

    (error_klasses - [ActiveRecord::AmbiguousSourceReflectionForThroughAssociation]).each do |error_klass|
      error_klass.new.inspect
    rescue ArgumentError
      raise "Instance of #{error_klass} can't be initialized with no arguments"
    end
  end
end
