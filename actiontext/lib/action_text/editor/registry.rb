# frozen_string_literal: true

module ActionText
  class Editor::Registry # :nodoc:
    def initialize(configurations)
      @configurations = configurations.to_h
      @editors = {}
    end

    def fetch(name)
      editors.fetch(name.to_sym) do |key|
        if configurations.include?(key)
          editors[key] = configurator.build(key)
        else
          if block_given?
            yield key
          else
            raise KeyError, "Missing configuration for the #{key} Action Text editor. " \
              "Configurations available for the #{configurations.keys.to_sentence} editors."
          end
        end
      end
    end

    def inspect # :nodoc:
      attrs = configurations.any? ?
        " configurations=[#{configurations.keys.map(&:inspect).join(", ")}]" : ""
      "#<#{self.class}#{attrs}>"
    end

    private
      attr_reader :configurations, :editors

      def configurator
        @configurator ||= Editor::Configurator.new(configurations)
      end
  end
end
