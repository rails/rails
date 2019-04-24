# frozen_string_literal: true

module ActiveModel
  # == Active \Model \Error
  #
  # Represents one single error
  class Error
    CALLBACKS_OPTIONS = [:if, :unless, :on, :allow_nil, :allow_blank, :strict]
    MESSAGE_OPTIONS = [:message]

    def initialize(base, attribute, type = :invalid, **options)
      @base = base
      @attribute = attribute
      @raw_type = type
      @type = type || :invalid
      @options = options
    end

    def initialize_dup(other)
      @attribute = @attribute.dup
      @raw_type = @raw_type.dup
      @type = @type.dup
      @options = @options.deep_dup
    end

    attr_reader :base, :attribute, :type, :raw_type, :options

    def message
      case raw_type
      when Symbol
        base.errors.generate_message(attribute, raw_type, options.except(*CALLBACKS_OPTIONS))
      else
        raw_type
      end
    end

    def detail
      { error: raw_type }.merge(options.except(*CALLBACKS_OPTIONS + MESSAGE_OPTIONS))
    end

    def full_message
      base.errors.full_message(attribute, message)
    end

    # See if error matches provided +attribute+, +type+ and +options+.
    def match?(attribute, type = nil, **options)
      if @attribute != attribute || (type && @type != type)
        return false
      end

      options.each do |key, value|
        if @options[key] != value
          return false
        end
      end

      true
    end

    def strict_match?(attribute, type, **options)
      return false unless match?(attribute, type, **options)

      full_message == Error.new(@base, attribute, type, **options).full_message
    end

    def ==(other)
      other.is_a?(self.class) && attributes_for_hash == other.attributes_for_hash
    end
    alias eql? ==

    def hash
      attributes_for_hash.hash
    end

    protected

      def attributes_for_hash
        [@base, @attribute, @raw_type, @options]
      end
  end
end
