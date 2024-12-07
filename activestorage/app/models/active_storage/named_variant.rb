# frozen_string_literal: true

class ActiveStorage::NamedVariant # :nodoc:
  attr_reader :transformations, :preprocessed

  def initialize(options)
    @preprocessed      = options[:preprocessed]
    @generation_option = options[:generation]
    @transformations   = options.except(:preprocessed, :generation)
  end

  def generation(record)
    return @generation_option if @generation_option
    preprocessed?(record) ? :delayed : :on_demand
  end

  private
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
