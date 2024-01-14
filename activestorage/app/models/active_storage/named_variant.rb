# frozen_string_literal: true

class ActiveStorage::NamedVariant # :nodoc:
  attr_reader :transformations, :preprocessed

  def initialize(options)
    @preprocessed      = options[:preprocessed]
    @process_option    = options[:process]
    @transformations   = options.except(:preprocessed, :process)

    if options.key?(:preprocessed)
      ActiveStorage.deprecator.warn(<<~MSG.squish)
        The :preprocessed option is deprecated and will be removed in Rails 9.0.
        Use the :process option instead. Replace `preprocessed: true` with `process: :later`
        and `preprocessed: false` with `process: :lazily`.
      MSG
    end
  end

  def process(record)
    return @process_option if @process_option
    preprocessed?(record) ? :later : :lazily
  end

  def transformations_for(record)
    callable = method(:callable_value).curry.call(record)
    transformations.transform_values(&callable)
  end

  private
    def preprocessed?(record)
      callable_value(record, preprocessed)
    end

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
