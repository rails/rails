# frozen_string_literal: true

module ActionView
  module Helpers # :nodoc:
    module ErrorWrappingHelper
      def content_tag(type, options, *)
        select_markup_helper?(type) ? super : error_wrapping(super)
      end

      def tag(type, options, *)
        tag_generate_errors?(options) ? error_wrapping(super) : super
      end

      def error_wrapping(html_tag)
        if has_error?
          @template_object.instance_exec(html_tag, self, &Base.field_error_proc)
        else
          html_tag
        end
      end

      def error_message
        errors[@method_name] if errors.respond_to?(:[])
      end

      private
        def has_error?
          (!errors.respond_to?(:include?) || errors.include?(@method_name)) && error_message.present?
        end

        def select_markup_helper?(type)
          ["optgroup", "option"].include?(type)
        end

        def tag_generate_errors?(options)
          options["type"] != "hidden"
        end
    end
  end
end
