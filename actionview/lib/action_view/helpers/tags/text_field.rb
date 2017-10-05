# frozen_string_literal: true

require_relative "placeholderable"

module ActionView
  module Helpers
    module Tags # :nodoc:
      class TextField < Base # :nodoc:
        include Placeholderable

        def render
          options = @options.stringify_keys
          options["size"] = options["maxlength"] unless options.key?("size")
          options["type"] ||= field_type
          options["value"] = options.fetch("value") { value_before_type_cast } unless field_type == "file"
          add_default_name_and_id(options)

          datalist_values = options.delete("datalist")

          if datalist_values
            options["list"] = options.fetch("list") { "#{options["id"]}_list" if options["id"] }
          end

          output = tag("input", options)

          if datalist_values
            option_tags = options_for_datalist(datalist_values)
            output += content_tag("datalist", option_tags, { "id" => options["list"] }.reject { |_, v| v.blank? })
          end

          output
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
