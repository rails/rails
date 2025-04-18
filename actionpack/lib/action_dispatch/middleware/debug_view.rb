# frozen_string_literal: true

# :markup: markdown

require "pp"

require "action_view"
require "action_view/base"

module ActionDispatch
  class DebugView < ActionView::Base # :nodoc:
    RESCUES_TEMPLATE_PATHS = [File.expand_path("templates", __dir__)]

    def initialize(assigns)
      paths = RESCUES_TEMPLATE_PATHS.dup
      lookup_context = ActionView::LookupContext.new(paths)
      super(lookup_context, assigns, nil)
    end

    def compiled_method_container
      self.class
    end

    def debug_params(params)
      clean_params = params.clone
      clean_params.delete("action")
      clean_params.delete("controller")

      if clean_params.empty?
        "None"
      else
        PP.pp(clean_params, +"", 200)
      end
    end

    def debug_headers(headers)
      if headers.present?
        headers.inspect.gsub(",", ",\n")
      else
        "None"
      end
    end

    def debug_hash(object)
      object.to_hash.sort_by { |k, _| k.to_s }.map { |k, v| "#{k}: #{v.inspect rescue $!.message}" }.join("\n")
    end

    def render(*)
      logger = ActionView::Base.logger

      if logger && logger.respond_to?(:silence)
        logger.silence { super }
      else
        super
      end
    end

    def protect_against_forgery?
      false
    end

    def params_valid?
      @request.parameters
    rescue ActionController::BadRequest
      false
    end
  end
end
