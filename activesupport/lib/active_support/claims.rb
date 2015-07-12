require 'active_support/time'

module ActiveSupport
  class Claims # :nodoc:
    class InvalidClaims < StandardError; end
    class ExpiredClaims < StandardError; end
    
    attr_reader :payload, :purpose, :expires_at
    UNIVERSAL_PURPOSE = 'universal'

    def initialize(payload:, **options)
      @payload = payload
      @purpose = options[:for] || UNIVERSAL_PURPOSE
      @expires_at = pick_expiration(options)
    end

    class << self
      attr_accessor :expires_in

      def verify!(claims, options = {})
        claims[:pld] if validate(claims, options, raises: true)
      end

      def verify(claims, options = {})
        claims[:pld] if validate(claims, options)
      end

      private
        def validate(claims, options, raises: false)
          if raises
            same_purpose?(claims[:for], options[:for]) || raise(InvalidClaims)
            fresh?(claims[:exp]) || raise(ExpiredClaims)
          else
            same_purpose?(claims[:for], options[:for]) && fresh?(claims[:exp])
          end
        end

        def fresh?(expiration)
          return true unless expiration

          Time.iso8601(expiration) > Time.now.utc
        end

        def same_purpose?(claims_purpose, other_purpose)
          claims_purpose == (other_purpose || UNIVERSAL_PURPOSE)
        end
    end

    def to_h
      { pld: @payload, for: @purpose.to_s }.tap do |claims|
        claims[:exp] = @expires_at.utc.iso8601(3) if @expires_at
      end
    end

    def ==(other)
      other.is_a?(self.class) && @purpose == other.purpose && @payload == other.payload
    end

    private
      def pick_expiration(options)
        return options[:expires_at] if options.key?(:expires_at)

        if expires_in = options.fetch(:expires_in) { self.class.expires_in }
          expires_in.from_now
        end
      end
  end
end
