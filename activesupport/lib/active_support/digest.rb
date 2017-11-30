# frozen_string_literal: true

module ActiveSupport
  class Digest #:nodoc:
    class <<self
      def hash_digest_class
        @hash_digest_class || ::Digest::MD5
      end

      def hash_digest_class=(klass)
        raise ArgumentError, "#{klass} is expected to implement hexdigest class method" unless klass.respond_to?(:hexdigest)
        @hash_digest_class = klass
      end

      def hexdigest(arg)
        new.hexdigest(arg)
      end
    end

    def initialize(digest_class: nil)
      @digest_class = digest_class || self.class.hash_digest_class
    end

    def hexdigest(arg)
      @digest_class.hexdigest(arg).truncate(32)
    end
  end
end
