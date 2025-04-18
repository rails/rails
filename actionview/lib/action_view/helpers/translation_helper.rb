# frozen_string_literal: true

require "action_view/helpers/tag_helper"
require "active_support/html_safe_translation"

module ActionView
  module Helpers # :nodoc:
    # = Action View Translation \Helpers
    module TranslationHelper
      extend ActiveSupport::Concern

      include TagHelper

      # Specify whether an error should be raised for missing translations.
      singleton_class.attr_accessor :raise_on_missing_translations

      included do
        mattr_accessor :debug_missing_translation, default: true
      end

      # Delegates to <tt>I18n#translate</tt> but also performs three additional
      # functions.
      #
      # First, it will ensure that any thrown +MissingTranslation+ messages will
      # be rendered as inline spans that:
      #
      # * Have a <tt>translation-missing</tt> class applied
      # * Contain the missing key as the value of the +title+ attribute
      # * Have a titleized version of the last key segment as text
      #
      # For example, the value returned for the missing translation key
      # <tt>"blog.post.title"</tt> will be:
      #
      #    <span
      #      class="translation_missing"
      #      title="translation missing: en.blog.post.title">Title</span>
      #
      # This allows for views to display rather reasonable strings while still
      # giving developers a way to find missing translations.
      #
      # If you would prefer missing translations to raise an error, you can
      # opt out of span-wrapping behavior globally by setting
      # <tt>config.i18n.raise_on_missing_translations = true</tt> or
      # individually by passing <tt>raise: true</tt> as an option to
      # <tt>translate</tt>.
      #
      # Second, if the key starts with a period <tt>translate</tt> will scope
      # the key by the current partial. Calling <tt>translate(".foo")</tt> from
      # the <tt>people/index.html.erb</tt> template is equivalent to calling
      # <tt>translate("people.index.foo")</tt>. This makes it less
      # repetitive to translate many keys within the same partial and provides
      # a convention to scope keys consistently.
      #
      # Third, the translation will be marked as <tt>html_safe</tt> if the key
      # has the suffix "_html" or the last element of the key is "html". Calling
      # <tt>translate("footer_html")</tt> or <tt>translate("footer.html")</tt>
      # will return an HTML safe string that won't be escaped by other HTML
      # helper methods. This naming convention helps to identify translations
      # that include HTML tags so that you know what kind of output to expect
      # when you call translate in a template and translators know which keys
      # they can provide HTML values for.
      #
      # To access the translated text along with the fully resolved
      # translation key, <tt>translate</tt> accepts a block:
      #
      #     <%= translate(".relative_key") do |translation, resolved_key| %>
      #       <span title="<%= resolved_key %>"><%= translation %></span>
      #     <% end %>
      #
      # This enables annotate translated text to be aware of the scope it was
      # resolved against.
      #
      def translate(key, **options)
        return key.map { |k| translate(k, **options) } if key.is_a?(Array)
        key = key&.to_s unless key.is_a?(Symbol)

        alternatives = if options.key?(:default)
          options[:default].is_a?(Array) ? options.delete(:default).compact : [options.delete(:default)]
        end

        options[:raise] = true if options[:raise].nil? && TranslationHelper.raise_on_missing_translations
        default = MISSING_TRANSLATION

        translation = while key || alternatives.present?
          if alternatives.blank? && !options[:raise].nil?
            default = NO_DEFAULT # let I18n handle missing translation
          end

          key = scope_key_by_partial(key)

          translated = ActiveSupport::HtmlSafeTranslation.translate(key, **options, default: default)

          break translated unless translated == MISSING_TRANSLATION

          if alternatives.present? && !alternatives.first.is_a?(Symbol)
            break alternatives.first && I18n.translate(nil, **options, default: alternatives)
          end

          first_key ||= key
          key = alternatives&.shift
        end

        if key.nil? && !first_key.nil?
          translation = missing_translation(first_key, options)
          key = first_key
        end

        block_given? ? yield(translation, key) : translation
      end
      alias :t :translate

      # Delegates to <tt>I18n.localize</tt> with no additional functionality.
      #
      # See https://www.rubydoc.info/gems/i18n/I18n/Backend/Base:localize
      # for more information.
      def localize(object, **options)
        I18n.localize(object, **options)
      end
      alias :l :localize

      private
        MISSING_TRANSLATION = -(2**60)
        private_constant :MISSING_TRANSLATION

        NO_DEFAULT = [].freeze
        private_constant :NO_DEFAULT

        def scope_key_by_partial(key)
          if key&.start_with?(".")
            if @virtual_path
              @_scope_key_by_partial_cache ||= {}
              @_scope_key_by_partial_cache[@virtual_path] ||= @virtual_path.gsub(%r{/_?}, ".")
              "#{@_scope_key_by_partial_cache[@virtual_path]}#{key}"
            else
              raise "Cannot use t(#{key.inspect}) shortcut because path is not available"
            end
          else
            key
          end
        end

        def missing_translation(key, options)
          locale = options[:locale] || I18n.locale

          i18n_exception = I18n::MissingTranslation.new(locale, key, options)
          I18n.exception_handler.call(i18n_exception, locale, key, options)

          keys = I18n.normalize_keys(locale, key, options[:scope])

          title = +"translation missing: #{keys.join(".")}"

          options.each do |name, value|
            unless name == :scope
              title << ", " << name.to_s << ": " << ERB::Util.html_escape(value)
            end
          end

          if ActionView::Base.debug_missing_translation
            content_tag("span", keys.last.to_s.titleize, class: "translation_missing", title: title)
          else
            title
          end
        end
    end
  end
end
