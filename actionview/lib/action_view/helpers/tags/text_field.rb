module ActionView
  module Helpers
    module Tags # :nodoc:
      class TextField < Base # :nodoc:
        SIZE  = "size".freeze
        VALUE = "value".freeze

        def render
          options = @options.stringify_keys
          options[SIZE] = options["maxlength".freeze] unless options.key?(SIZE)
          options["type".freeze] ||= field_type
          options[VALUE] = options.fetch(VALUE) { value_before_type_cast(object) } unless field_type == "file".freeze
          options[VALUE] &&= ERB::Util.html_escape(options[VALUE])
          add_default_name_and_id(options)
          tag("input".freeze, options)
        end

        class << self
          def field_type
            @field_type ||= self.name.split("::".freeze).last.sub("Field".freeze, "".freeze).downcase
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
