# frozen_string_literal: true

class ActiveStorage::NamedVariant # :nodoc:
  attr_reader :transformations, :preprocessed

  def initialize(options)
    @preprocessed      = options[:preprocessed]
    @process_option    = options[:process]
    @transformations   = options.except(:preprocessed, :process)
  end

  def process(record)
    return @process_option if @process_option
    preprocessed?(record) ? :later : :lazily
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
