# frozen_string_literal: true

require "action_view/helpers/tags/placeholderable"

module ActionView
  module Helpers
    module Tags # :nodoc:
      class TextField < Base # :nodoc:
        include Placeholderable

        def render
          options = @options.stringify_keys

          if ActionView::Helpers::FormHelper.text_field_maxlength_implies_size &&
             options.key?("maxlength") && !options.key?("size")
            ActionView.deprecator.warn(
              "Setting maxlength without size will no longer imply size in Rails 8.2. " \
              "Specify size explicitly if needed, or set " \
              "ActionView::Helpers::FormHelper.text_field_maxlength_implies_size = false " \
              "to opt into the new behavior early."
            )
            options["size"] = options["maxlength"]
          end

          options["type"] ||= field_type
          options["value"] = options.fetch("value") { value_before_type_cast } unless field_type == "file"
          add_default_name_and_id(options)
          tag("input", options)
        end

        class << self
          def field_type
            @field_type ||= name.split("::").last.sub("Field", "").downcase
          end
        end

        private
          def field_type
            self.class.field_type
          end
      end
    end
  end
end
