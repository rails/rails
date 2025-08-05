# frozen_string_literal: true

module RailInspector
  class Configuring
    class Document
      class << self
        def parse(text)
          before, versioned_defaults, general_config, after =
            text
              .split("\n")
              .slice_before do |line|
                [
                  "### Versioned Default Values",
                  "### Rails General Configuration",
                  "### Configuring Assets"
                ].include?(line)
              end
              .to_a

          new(before, versioned_defaults, general_config, after)
        end
      end

      attr_accessor :general_config, :versioned_defaults

      def initialize(before, versioned_defaults, general_config, after)
        @before, @versioned_defaults, @general_config, @after =
          before, versioned_defaults, general_config, after
      end

      def to_s
        (@before + @versioned_defaults + @general_config + @after).join("\n") +
          "\n"
      end
    end
  end
end
