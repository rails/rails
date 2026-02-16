# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class FileField < TextField # :nodoc:
        def render
          if @object && !@options.key?(:multiple)
            if @object.class.respond_to?(:reflect_on_attachment)
              reflection = @object.class.reflect_on_attachment(@method_name)
              if reflection&.macro == :has_many_attached
                @options[:multiple] = true
              end
            end
          end

          include_hidden = @options.delete(:include_hidden)
          if @options[:accept].is_a?(Array)
            @options[:accept] = @options[:accept].join(",")
          end
          options = @options.stringify_keys
          add_default_name_and_field(options)

          if options["multiple"] && include_hidden
            hidden_field_for_multiple_file(options) + super
          else
            super
          end
        end

        private
          def hidden_field_for_multiple_file(options)
            tag_options = { "name" => options["name"], "type" => "hidden", "value" => "" }
            tag_options["autocomplete"] = "off" unless ActionView::Base.remove_hidden_field_autocomplete
            tag("input", tag_options)
          end
      end
    end
  end
end
