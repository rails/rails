# frozen_string_literal: true

module ActionView # :nodoc:
  class Template # :nodoc:
    # = Action View Template Handlers
    module Handlers # :nodoc:
      autoload :Raw, "action_view/template/handlers/raw"
      autoload :ERB, "action_view/template/handlers/erb"
      autoload :Html, "action_view/template/handlers/html"
      autoload :Builder, "action_view/template/handlers/builder"

      @template_handlers = {}.freeze
      @template_extensions = [].freeze
      @default_template_handler = nil

      class << self
        attr_reader :template_handlers, :default_template_handler

        def extensions
          @template_extensions
        end

        def register(*extensions, handler)
          handler = ActiveSupport::Ractors.try_shareable_proc(handler) if handler.is_a?(Proc)
          handlers = @template_handlers.dup
          extensions.each do |extension|
            handlers[extension.to_sym] = handler
          end
          @template_handlers = handlers.freeze
          @template_extensions = @template_handlers.keys.freeze
        end

        def register_default(extension, handler)
          register(extension, handler)
          @default_template_handler = @template_handlers[extension.to_sym]
        end

        def unregister(*extensions)
          handlers = @template_handlers.dup
          extensions.each do |extension|
            handler = handlers.delete extension.to_sym
            @default_template_handler = nil if @default_template_handler == handler
          end
          @template_handlers = handlers.freeze
          @template_extensions = @template_handlers.keys.freeze
        end
      end

      def register_template_handler(*extensions, handler)
        raise(ArgumentError, "Extension is required") if extensions.empty?
        Handlers.register(*extensions, handler)
      end

      # Opposite to register_template_handler.
      def unregister_template_handler(*extensions)
        Handlers.unregister(*extensions)
      end

      def handler_for_extension(extension)
        handler = Handlers.template_handlers[extension.to_sym] if extension
        handler || Handlers.default_template_handler
      end

      register_default :raw, Raw.new.freeze
      register :erb, ERB.new.freeze
      register :html, Html.new.freeze
      register :builder, Builder.new.freeze
      register :ruby, ActiveSupport::Ractors.shareable_lambda { |_, source| source }
    end
  end
end
