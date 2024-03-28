# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/enumerable"

module ActionView
  module Helpers # :nodoc:
    module ActiveModelHelper
    end

    # = Active \Model Instance Tag \Helpers
    module ActiveModelInstanceTag
      class TagBuilder < ActionView::Helpers::TagHelper::TagBuilder # :nodoc:
        def initialize(view_context, wrapper)
          super(view_context)
          @wrapper = wrapper
        end

        def self_closing_tag_string(name, options, escape = true, tag_suffix = " />")
          generate_errors?(options) ? @wrapper.error_wrapping(super) : super
        end

        def tag_string(name, content = nil, escape: true, **options, &block)
          generate_errors?(options) ? @wrapper.error_wrapping(super) : super
        end

        private
          def generate_errors?(options)
            options["type"] != "hidden"
          end
      end

      def object
        @active_model_object ||= begin
          object = super
          object.respond_to?(:to_model) ? object.to_model : object
        end
      end

      def content_tag(type, options, *)
        select_markup_helper?(type) ? super : error_wrapping(super)
      end

      def tag
        TagBuilder.new(@template_object, self)
      end

      def error_wrapping(html_tag)
        if object_has_errors?
          @template_object.instance_exec(html_tag, self, &Base.field_error_proc)
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
    end
  end
end
