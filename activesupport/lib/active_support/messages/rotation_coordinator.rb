# frozen_string_literal: true

require "active_support/core_ext/hash/slice"

module ActiveSupport
  module Messages
    class RotationCoordinator # :nodoc:
      attr_accessor :transitional

      def initialize(&secret_generator)
        raise ArgumentError, "A secret generator block is required" unless secret_generator
        @secret_generator = secret_generator
        @rotate_options = []
        @on_rotation = nil
        @codecs = {}
      end

      def [](salt)
        @codecs[salt] ||= build_with_rotations(salt)
      end

      def []=(salt, codec)
        @codecs[salt] = codec
      end

      def rotate(**options, &block)
        raise ArgumentError, "Options cannot be specified when using a block" if block && !options.empty?
        changing_configuration!

        @rotate_options << (block || options)

        self
      end

      def prepend(**options, &block)
        raise ArgumentError, "Options cannot be specified when using a block" if block && !options.empty?
        changing_configuration!

        @rotate_options.unshift(block || options)

        self
      end

      def rotate_defaults
        rotate()
      end

      def clear_rotations
        changing_configuration!
        @rotate_options.clear
        self
      end

      def on_rotation(&callback)
        changing_configuration!
        @on_rotation = callback
      end

      private
        def changing_configuration!
          if @codecs.any?
            raise <<~MESSAGE
              Cannot change #{self.class} configuration after it has already been applied.

              The configuration has been applied with the following salts:
              #{@codecs.keys.map { |salt| "- #{salt.inspect}" }.join("\n")}
            MESSAGE
          end
        end

        def normalize_options(options)
          options = options.dup

          options[:secret_generator] ||= @secret_generator

          secret_generator_kwargs = options[:secret_generator].parameters.
            filter_map { |type, name| name if type == :key || type == :keyreq }
          options[:secret_generator_options] = options.extract!(*secret_generator_kwargs)

          options[:on_rotation] = @on_rotation

          options
        end

        def build_with_rotations(salt)
          rotate_options = @rotate_options.map { |options| options.is_a?(Proc) ? options.(salt) : options }
          transitional = self.transitional && rotate_options.first
          rotate_options.compact!
          rotate_options[0..1] = rotate_options[0..1].reverse if transitional
          rotate_options = rotate_options.map { |options| normalize_options(options) }.uniq

          raise "No options have been configured for #{salt}" if rotate_options.empty?

          rotate_options.map { |options| build(salt.to_s, **options) }.reduce(&:fall_back_to)
        end

        def build(salt, secret_generator:, secret_generator_options:, **options)
          raise NotImplementedError
        end
    end
  end
end
