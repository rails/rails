# frozen_string_literal: true

module ActiveSupport
  module Messages
    class RotationConfiguration # :nodoc:
      attr_reader :signed, :encrypted

      def initialize
        @signed, @encrypted = [], []
      end

      def rotate(kind = nil, **options)
        case kind
        when :signed
          @signed << options
        when :encrypted
          @encrypted << options
        else
          rotate :signed, options
          rotate :encrypted, options
        end
      end
    end
  end
end
