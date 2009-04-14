require 'digest/md5'

module Rack
  module Auth
    module Digest
      # Rack::Auth::Digest::Nonce is the default nonce generator for the
      # Rack::Auth::Digest::MD5 authentication handler.
      #
      # +private_key+ needs to set to a constant string.
      #
      # +time_limit+ can be optionally set to an integer (number of seconds),
      # to limit the validity of the generated nonces.

      class Nonce

        class << self
          attr_accessor :private_key, :time_limit
        end

        def self.parse(string)
          new(*string.unpack("m*").first.split(' ', 2))
        end

        def initialize(timestamp = Time.now, given_digest = nil)
          @timestamp, @given_digest = timestamp.to_i, given_digest
        end

        def to_s
          [([ @timestamp, digest ] * ' ')].pack("m*").strip
        end

        def digest
          ::Digest::MD5.hexdigest([ @timestamp, self.class.private_key ] * ':')
        end

        def valid?
          digest == @given_digest
        end

        def stale?
          !self.class.time_limit.nil? && (@timestamp - Time.now.to_i) < self.class.time_limit
        end

        def fresh?
          !stale?
        end

      end
    end
  end
end
