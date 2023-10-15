# frozen_string_literal: true

module Rails
  module Testing
    module CapybaraExtensions
      module_function def install(selector_name)
        Capybara.modify_selector(selector_name) do
          expression_filter(:data, Hash, skip_if: nil) do |xpath, data|
            expression = builder(xpath)

            CapybaraExtensions.unnest_attributes(data, under: "data").reduce(expression) do |scope, (key, value)|
              scope.add_attribute_conditions(key => value)
            end
          end

          expression_filter(:aria, Hash, skip_if: nil) do |xpath, aria|
            expression = builder(xpath)

            CapybaraExtensions.unnest_attributes(aria, under: "aria").reduce(expression) do |scope, (key, value)|
              scope.add_attribute_conditions(key => value)
            end
          end

          describe(:expression_filters) do |aria: {}, data: {}, **|
            describe_all_expression_filters(
              **CapybaraExtensions.unnest_attributes(aria, under: "aria"),
              **CapybaraExtensions.unnest_attributes(data, under: "data")
            )
          end
        end
      end

      private
        module_function def unnest_attributes(attributes, under:)
          nested_under_data = under.to_s == "data"

          attributes
            .transform_keys { |key| [under, key.to_s.dasherize].join("-").to_sym }
            .transform_values do |value|
              case value
              when Hash then nested_under_data ? value.to_json : value
              when Array then nested_under_data ? value.to_json : value.join(" ")
              else value
              end
            end
        end
    end
  end
end
