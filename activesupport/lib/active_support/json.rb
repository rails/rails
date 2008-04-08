

module ActiveSupport
  # If true, use ISO 8601 format for dates and times.  Otherwise, fall back to the ActiveSupport legacy format.
  mattr_accessor :use_standard_json_time_format

  class << self
    def escape_html_entities_in_json
      @escape_html_entities_in_json
    end

    def escape_html_entities_in_json=(value)
      ActiveSupport::JSON::Encoding.escape_regex = \
        if value
          /[\010\f\n\r\t"\\><&]/
        else
          /[\010\f\n\r\t"\\]/
        end
      @escape_html_entities_in_json = value
    end
  end

  module JSON
    RESERVED_WORDS = %w(
      abstract      delete        goto          private       transient
      boolean       do            if            protected     try
      break         double        implements    public        typeof
      byte          else          import        return        var
      case          enum          in            short         void
      catch         export        instanceof    static        volatile
      char          extends       int           super         while
      class         final         interface     switch        with
      const         finally       long          synchronized
      continue      float         native        this
      debugger      for           new           throw
      default       function      package       throws
    ) #:nodoc:

    class << self
      def valid_identifier?(key) #:nodoc:
        key.to_s =~ /^[[:alpha:]_$][[:alnum:]_$]*$/ && !reserved_word?(key)
      end

      def reserved_word?(key) #:nodoc:
        RESERVED_WORDS.include?(key.to_s)
      end
    end
  end
end

require 'active_support/json/encoding'
require 'active_support/json/decoding'
