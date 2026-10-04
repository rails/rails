# frozen_string_literal: true

class ActiveStorage::NamedVariant # :nodoc:
  PROCESS_MODES = [ :immediately, :later, :lazily ].freeze

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
    return preprocessed?(record) ? :later : :lazily unless @process_option

    process_mode(record)
  end

  private
    # The :process option is either a mode, or a Proc or the name of a record
    # method returning one, so an application can decide per record whether a
    # variant is worth processing ahead of time.
    def process_mode(record)
      mode =
        case @process_option
        when *PROCESS_MODES
          @process_option
        when Proc
          @process_option.call(record)
        when Symbol
          record.respond_to?(@process_option, true) ? record.send(@process_option) : @process_option
        else
          @process_option
        end

      unless PROCESS_MODES.include?(mode)
        raise ArgumentError, "Unknown process option: #{mode.inspect}. Valid options are :immediately, :later, :lazily."
      end

      mode
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
