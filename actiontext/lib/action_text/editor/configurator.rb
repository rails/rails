# frozen_string_literal: true

module ActionText
  class Editor::Configurator # :nodoc:
    attr_reader :configurations

    def initialize(configurations)
      @configurations = configurations.deep_symbolize_keys
    end

    def build(editor_name)
      config = config_for(editor_name.to_sym)
      resolve(editor_name).new(editor_name, config)
    end

    private
      def config_for(name)
        configurations.fetch name do
          raise "Missing configuration for the #{name.inspect} Action Text editor. Configurations available for #{configurations.keys.inspect}"
        end
      end

      def resolve(class_name)
        require "action_text/editor/#{class_name.to_s.underscore}_editor"
        ActionText::Editor.const_get(:"#{class_name.to_s.classify}Editor")
      rescue LoadError => e
        raise "Missing editor adapter for #{class_name.inspect} defined in #{e.path}."
      end
  end
end
