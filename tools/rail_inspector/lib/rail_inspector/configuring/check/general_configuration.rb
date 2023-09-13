# frozen_string_literal: true

require_relative "../../visitor/attribute"

module RailInspector
  class Configuring
    module Check
      class GeneralConfiguration
        attr_reader :checker

        def initialize(checker)
          @checker = checker
        end

        def check
          header, *config_sections = documented_general_config

          non_nested_accessors =
            general_accessors.reject do |a|
              config_sections.any? { |section| /\.#{a}\./.match?(section[0]) }
            end

          non_nested_accessors.each do |accessor|
            config_header = "#### `config.#{accessor}`"

            unless config_sections.any? { |section| section[0] == config_header }
              checker.errors << config_header
              config_sections << [config_header, "", "FIXME", ""]
            end
          end

          checker.doc.general_config =
            [header] +
              config_sections.sort_by { |section| section[0].split("`")[1] }
        end

        private
          APP_CONFIG_CONST = "Rails::Application::Configuration"

          def app_config_tree
            checker.parse(APPLICATION_CONFIGURATION_PATH)
          end

          def documented_general_config
            checker
              .doc
              .general_config
              .slice_before { |line| line.start_with?("####") }
              .to_a
          end

          def general_accessors
            visitor.attribute_map[APP_CONFIG_CONST]["attr_accessor"]
          end

          def visitor
            @visitor ||=
              begin
                visitor = Visitor::Attribute.new
                visitor.visit(app_config_tree)
                visitor
              end
          end
      end
    end
  end
end
