# frozen_string_literal: true

module ActiveSupport
  module Messages
    class RotationConfiguration # :nodoc:
      attr_reader :signed, :encrypted

      def initialize
        @signed, @encrypted = [], []
      end

      def rotate(kind, *args, **options)
        case kind
        when :signed
          if options&.any?
            @signed << (args << options)
          else
            @signed << args
          end
        when :encrypted
          if options&.any?
            @encrypted << (args << options)
          else
            @encrypted << args
          end
        end
      end
    end
  end
end
