# frozen_string_literal: true

module RailInspector
  class Configuring
    class Document
      class << self
        def parse(text)
          before, *versioned_defaults, general_config, after =
            text
              .split("\n")
              .slice_before do |line|
                [
                  "#### Default Values for Target Version",
                  "### Rails General Configuration",
                  "### Configuring Assets"
                ].any? { |s| line.start_with?(s) }
              end
              .to_a

          new(before, versioned_defaults.flatten.join("\n"), general_config, after)
        end
      end

      attr_accessor :general_config, :versioned_defaults

      def initialize(before, versioned_defaults, general_config, after)
        @before, @versioned_defaults, @general_config, @after =
          before, versioned_defaults, general_config, after
      end

      def to_s
        (@before + [@versioned_defaults] + @general_config + @after).join("\n") +
          "\n"
      end
    end
  end
end
