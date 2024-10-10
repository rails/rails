# frozen_string_literal: true

class ActiveStorage::NamedVariant # :nodoc:
  attr_reader :transformations, :preprocessed, :before_attached, :after_attached

  def initialize(transformations)
    @preprocessed = transformations[:preprocessed]
    @before_attached = transformations[:before_attached]
    @after_attached = transformations[:after_attached]
    @transformations = transformations.except(:preprocessed, :before_attached, :after_attached)
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
