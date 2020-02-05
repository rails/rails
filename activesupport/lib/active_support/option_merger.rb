# frozen_string_literal: true

require "active_support/core_ext/hash/deep_merge"

module ActiveSupport
  class OptionMerger #:nodoc:
    instance_methods.each do |method|
      undef_method(method) if !/^(__|instance_eval|class|object_id)/.match?(method)
    end

    def initialize(context, options)
      @context, @options = context, options
    end

    private
      def method_missing(method, *arguments, &block)
        options = nil
        if arguments.first.is_a?(Proc)
          proc = arguments.pop
          arguments << lambda { |*args| @options.deep_merge(proc.call(*args)) }
        elsif arguments.last.respond_to?(:to_hash)
          options = @options.deep_merge(arguments.pop)
        else
          options = @options
        end

        invoke_method(method, arguments, options, &block)
      end

      if RUBY_VERSION >= "2.7"
        def invoke_method(method, arguments, options, &block)
          if options
            @context.__send__(method, *arguments, **options, &block)
          else
            @context.__send__(method, *arguments, &block)
          end
        end
      else
        def invoke_method(method, arguments, options, &block)
          arguments << options if options
          @context.__send__(method, *arguments, &block)
        end
      end
  end
end
