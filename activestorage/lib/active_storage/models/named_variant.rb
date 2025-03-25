# frozen_string_literal: true

class ActiveStorage::NamedVariant # :nodoc:
  attr_reader :transformations, :preprocessed

  def initialize(transformations)
    @preprocessed = transformations[:preprocessed]
    @transformations = transformations.except(:preprocessed)
  end

  def preprocessed?(record)
    case preprocessed
    when Symbol
      record.send(preprocessed)
    when Proc
      preprocessed.call(record)
    else
      preprocessed
    end
  end
end
