# frozen_string_literal: true

module ActionText
  class Editor::Registry # :nodoc:
    attr_reader :configurator

    def initialize(configurations)
      @configurator = Editor::Configurator.new(configurations)
      @editors = {}
    end

    def store(name, editor)
      @editors[name.to_sym] = editor
    end

    def fetch(name)
      @editors.fetch(name.to_sym) do |key|
        store(key, @configurator.build(key))
      end
    end
  end
end
