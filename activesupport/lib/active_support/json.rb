require 'active_support/json/encoding'
require 'active_support/json/decoding'

module ActiveSupport
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
