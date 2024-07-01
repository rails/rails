# frozen_string_literal: true

class ActiveStorage::NamedVariant # :nodoc:
  attr_reader :transformations, :preprocessed

  def initialize(transformations)
    @preprocessed = transformations[:preprocessed]
    @immediate = transformations[:immediate]
    @transformations = transformations.except(:preprocessed, :immediate)
  end

  def preprocessed?(record)
    option(preprocessed, record)
  end

  def immediate?(record)
    option(@immediate, record)
  end

  private
    def option(value, record)
      case value
      when Symbol
        record.send(value)
      when Proc
        value.call(record)
      else
        value
      end
    end
end
