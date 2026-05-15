# frozen_string_literal: true

module ActionText
  class Editor::Configurator # :nodoc:
    attr_reader :configurations

    def initialize(configurations)
      @configurations = configurations
    end

    def build(editor_name)
      editor_class = resolve(editor_name.to_s)
      options = config_for(editor_name.to_sym)

      editor_class.new(options)
    end

    def inspect # :nodoc:
      attrs = configurations.any? ?
        " configurations=[#{configurations.keys.map(&:inspect).join(", ")}]" : ""
      "#<#{self.class}#{attrs}>"
    end

    private
      def config_for(name)
        configurations.fetch name do
          raise "Missing configuration for the #{name.inspect} Action Text editor. Configurations available for #{configurations.keys.inspect}"
        end
      end

      def resolve(class_name)
        require "action_text/editor/#{class_name.underscore}_editor"

        Editor.const_get(:"#{class_name.camelize}Editor")
      rescue LoadError
        raise "Missing editor adapter for #{class_name.inspect}"
      end
  end
end
