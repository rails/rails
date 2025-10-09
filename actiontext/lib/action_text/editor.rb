# frozen_string_literal: true

module ActionText
  class Editor # :nodoc:
    extend ActiveSupport::Autoload

    autoload :Configurator
    autoload :Registry

    attr_reader :options

    def initialize(options)
      @options = options
    end

    def to_action_text_html(editor_html)
      editor_html
    end

    def to_editor_html(action_text_html)
      action_text_html
    end

    def editor_tag(options = {})
      raise NotImplementedError.new("#editor_tag not implemented")
    end
  end
end
