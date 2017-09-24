# frozen_string_literal: true

module ActiveSupport
  module Messages
    class RotationConfiguration # :nodoc:
      attr_reader :signed, :encrypted

      def initialize
        @signed, @encrypted = [], []
      end

      def rotate(kind = nil, *args)
        case kind
        when :signed
          @signed << args
        when :encrypted
          @encrypted << args
        else
          rotate :signed, args
          rotate :encrypted, args
        end
      end
    end
  end
end
