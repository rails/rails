# frozen_string_literal: true

require "action_view/helpers/tags/placeholderable"

module ActionView
  module Helpers
    module Tags # :nodoc:
      class TextField < Base # :nodoc:
        include Placeholderable

        # def render
        #   options = @options.stringify_keys
        #   options["size"] = options["maxlength"] unless options.key?("size")
        #   options["type"] ||= field_type
        #   options["value"] = options.fetch("value") { value_before_type_cast } unless field_type == "file"
        #   add_default_name_and_id(options)
        #   # puts "options: #{options}"
        #   options
        #   # tag("input", options)
        # end

        def to_s
          # puts "TO_S TO_S TO_S TO_S TO_S"
          options = attributes
          tag("input", options)
        end

        def attributes
          # puts "ATTRSSSS"
          options = @options.stringify_keys
          options["size"] = options["maxlength"] unless options.key?("size")
          options["type"] ||= field_type
          options["value"] = options.fetch("value") { value_before_type_cast } unless field_type == "file"
          add_default_name_and_id(options)
          options
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
