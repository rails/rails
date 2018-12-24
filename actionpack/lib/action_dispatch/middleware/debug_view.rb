# frozen_string_literal: true

require "pp"

require "action_view"
require "action_view/base"

module ActionDispatch
  class DebugView < ActionView::Base # :nodoc:
    RESCUES_TEMPLATE_PATH = File.expand_path("templates", __dir__)

    def initialize(assigns)
      super([RESCUES_TEMPLATE_PATH], assigns)
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
  end
end
