# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/enumerable"

module ActionView
  # = Active Model Helpers
  module Helpers #:nodoc:
    module ActiveModelHelper
    end

    module ActiveModelInstanceTag
      def object
        @active_model_object ||= begin
          object = super
          object.respond_to?(:to_model) ? object.to_model : object
        end
      end

      def content_tag(type, options, *)
        select_markup_helper?(type) ? super : error_wrapping(super)
      end

      def tag(type, options, *)
        tag_generate_errors?(options) ? error_wrapping(super) : super
      end

      def error_wrapping(html_tag)
        if object_has_errors?
          Base.field_error_proc.call(html_tag, self)
        else
          html_tag
        end
      end

      def error_message
        object.errors[@method_name]
      end

      private
        def object_has_errors?
          object.respond_to?(:errors) && object.errors.respond_to?(:[]) && error_message.present?
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
