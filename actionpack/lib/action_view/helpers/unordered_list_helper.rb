# encoding: utf-8

module ActionView
  # = Action View Helpers
  module Helpers #:nodoc:

    # Provides methods for generating markup from Enumerables
    module UnorderedListHelper

      def unordered_list(klass_or_enum, options = {}, &block)
        klass = klass_or_enum
        enum = []

        if block_given?
          klass = klass_or_enum.map(&:class).first.to_s.downcase
          enum = klass_or_enum
        else
          klass = klass.to_s
        end

        content_tag :ul, { class: klass.pluralize }.merge(options) do
          list_items = []
          enum.each do |item|
            li = content_tag(:li, class: klass) { yield item }
            list_items << li
          end

          list_items.join.html_safe
        end
      end
      alias_method :ul, :unordered_list
    end
  end
end
