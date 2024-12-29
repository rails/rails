# frozen_string_literal: true

require_relative "../../visitor/attribute"

module RailInspector
  class Configuring
    module Check
      class GeneralConfiguration
        class AccessorParser
          def initialize(checker)
            @checker = checker
          end

          def call
            visitor = Visitor::Attribute.new
            visitor.visit(app_config_tree)
            visitor.attribute_map[APP_CONFIG_CONST][:attr_accessor]
          end

          private
            APP_CONFIG_CONST = "Rails::Application::Configuration"

            def app_config_tree
              @checker.parse(APPLICATION_CONFIGURATION_PATH)
            end
        end

        attr_reader :checker, :expected_accessors

        def initialize(checker, expected_accessors: AccessorParser.new(checker).call)
          @checker = checker
          @expected_accessors = expected_accessors
        end

        def check
          header, *config_sections = documented_general_config

          non_nested_accessors =
            expected_accessors.reject do |a|
              config_sections.any? { |section| /\.#{a}\./.match?(section[0]) }
            end

          non_nested_accessors.each do |accessor|
            config_header = "#### `config.#{accessor}`"

            unless config_sections.any? { |section| section[0] == config_header }
              checker.errors << "Missing configuration: #{config_header}"
              config_sections << [config_header, "", "FIXME", ""]
            end
          end

          new_config = header + config_sections.sort_by { |section| section[0].split("`")[1] }.flatten

          return if new_config == checker.doc.general_config

          checker.errors << "General Configuration is not alphabetical"

          checker.doc.general_config = new_config
        end

        private
          def documented_general_config
            checker
              .doc
              .general_config
              .slice_before { |line| line.start_with?("####") }
              .to_a
          end
      end
    end
  end
end
