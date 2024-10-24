# frozen_string_literal: true

class ActiveStorage::NamedVariant # :nodoc:
  attr_reader :transformations, :preprocessed

  def initialize(transformations)
    @preprocessed = transformations[:preprocessed]
    @transformations = transformations.except(:preprocessed)
  end

  def preprocessed?(record)
    callable_value(record, preprocessed)
  end

  def transformations_for(record)
    callable = method(:callable_value).curry.call(record)
    transformations.transform_values(&callable)
  end

  private
    def callable_value(record, method_or_value)
      case method_or_value
      when Symbol
        record.send(method_or_value)
      when Proc
        method_or_value.call(record)
      else
        method_or_value
      end
    end
end
