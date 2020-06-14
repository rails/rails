# frozen_string_literal: true

module ActiveSupport
  module Messages
    class RotationConfiguration # :nodoc:
      attr_reader :signed, :encrypted, :active_storage

      def initialize
        @signed, @encrypted, @active_storage = [], [], []
      end

      def rotate(kind, *args, **options)
        args << options unless options.empty?
        case kind
        when :signed
          @signed << args
        when :encrypted
          @encrypted << args
        when :active_storage
          @active_storage << args
        end
      end
    end
  end
end
