# frozen_string_literal: true

module ActiveSupport
  module Messages
    module Rotator # :nodoc:
      def initialize(*args, on_rotation: nil, **options)
        super(*args, **options)
        @args = args
        @options = options
        @rotations = []
        @on_rotation = on_rotation
      end

      def rotate(*args, **options)
        fall_back_to build_rotation(*args, **options)
      end

      def on_rotation(&on_rotation)
        @on_rotation = on_rotation
        self
      end

      def fall_back_to(fallback)
        @rotations << fallback
        self
      end

      def read_message(message, on_rotation: @on_rotation, **options)
        if @rotations.empty?
          super(message, **options)
        else
          thrown, error = catch_rotation_error do
            return super(message, **options)
          end

          @rotations.each do |rotation|
            catch_rotation_error do
              value = rotation.read_message(message, **options)
              on_rotation&.call
              return value
            end
          end

          throw thrown, error
        end
      end

      private
        def build_rotation(*args, **options)
          self.class.new(*args, *@args.drop(args.length), **@options, **options)
        end

        def catch_rotation_error(&block)
          error = catch :invalid_message_format do
            error = catch :invalid_message_serialization do
              return [nil, block.call]
            end
            return [:invalid_message_serialization, error]
          end
          [:invalid_message_format, error]
        end
    end
  end
end
