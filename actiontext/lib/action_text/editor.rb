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

    def to_action_text_html(content)
      content.to_html
    end

    def to_editor_html(content)
      content.to_html
    end

    def editor_name
      self.class.name.demodulize.delete_suffix("Editor").underscore
    end

    def editor_tag(...)
      Tag.new(editor_name, ...)
    end
  end

  class Editor::Tag # :nodoc:
    cattr_accessor(:id, instance_accessor: false) { 0 }

    attr_reader :editor_name
    attr_reader :options
    attr_reader :name

    def initialize(editor_name, options = {})
      @editor_name = editor_name
      @options = options
      @name = options.delete(:name)
    end

    def element_name
      "#{editor_name}-editor"
    end

    def render_in(view_context)
      options[:class] ||= "#{editor_name}-content"

      view_context.content_tag(element_name, nil, options)
    end
  end
end
