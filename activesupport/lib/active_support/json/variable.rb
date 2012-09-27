require 'active_support/deprecation'

module ActiveSupport
  module JSON
    # Deprecated: A string that returns itself as its JSON-encoded form.
    class Variable < String
      def initialize(*args)
        ActiveSupport::Deprecation.warn 'ActiveSupport::JSON::Variable is deprecated and will be removed in Rails 4.1. ' \
                                        'For your own custom JSON literals, define #as_json and #encode_json yourself.'
        super
      end

      def as_json(options = nil) self end #:nodoc:
      def encode_json(encoder) self end #:nodoc:
    end
  end
end
