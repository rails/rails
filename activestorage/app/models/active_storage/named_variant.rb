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
