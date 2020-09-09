# frozen_string_literal: true

require "action_view/helpers/tag_helper"
require "active_support/core_ext/string/access"
require "i18n/exceptions"

module ActionView
  # = Action View Translation Helpers
  module Helpers #:nodoc:
    module TranslationHelper
      extend ActiveSupport::Concern

      include TagHelper

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
      # <tt>ActionView::Base.raise_on_missing_translations = true</tt> or
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
      def translate(key, **options)
        if options.has_key?(:default)
          remaining_defaults = Array.wrap(options.delete(:default)).compact
          options[:default] = remaining_defaults unless remaining_defaults.first.kind_of?(Symbol)
        end

        # If the user has explicitly decided to NOT raise errors, pass that option to I18n.
        # Otherwise, tell I18n to raise an exception, which we rescue further in this method.
        # Note: `raise_error` refers to us re-raising the error in this method. I18n is forced to raise by default.
        if options[:raise] == false
          raise_error = false
          i18n_raise = false
        else
          raise_error = options[:raise] || ActionView::Base.raise_on_missing_translations
          i18n_raise = true
        end

        if html_safe_translation_key?(key)
          html_safe_options = options.dup

          options.except(*I18n::RESERVED_KEYS).each do |name, value|
            unless name == :count && value.is_a?(Numeric)
              html_safe_options[name] = ERB::Util.html_escape(value.to_s)
            end
          end

          html_safe_options[:default] = MISSING_TRANSLATION unless html_safe_options[:default].blank?

          translation = I18n.translate(scope_key_by_partial(key), **html_safe_options.merge(raise: i18n_raise))

          if translation.equal?(MISSING_TRANSLATION)
            options[:default].first
          elsif translation.respond_to?(:map)
            translation.map { |element| element.respond_to?(:html_safe) ? element.html_safe : element }
          else
            translation.respond_to?(:html_safe) ? translation.html_safe : translation
          end
        else
          I18n.translate(scope_key_by_partial(key), **options.merge(raise: i18n_raise))
        end
      rescue I18n::MissingTranslationData => e
        if remaining_defaults.present?
          translate remaining_defaults.shift, **options.merge(default: remaining_defaults)
        else
          raise e if raise_error

          keys = I18n.normalize_keys(e.locale, e.key, e.options[:scope])
          title = +"translation missing: #{keys.join('.')}"

          interpolations = options.except(:default, :scope)
          if interpolations.any?
            title << ", " << interpolations.map { |k, v| "#{k}: #{ERB::Util.html_escape(v)}" }.join(", ")
          end

          return title unless ActionView::Base.debug_missing_translation

          content_tag("span", keys.last.to_s.titleize, class: "translation_missing", title: title)
        end
      end
      alias :t :translate

      # Delegates to <tt>I18n.localize</tt> with no additional functionality.
      #
      # See https://www.rubydoc.info/github/svenfuchs/i18n/master/I18n/Backend/Base:localize
      # for more information.
      def localize(object, **options)
        I18n.localize(object, **options)
      end
      alias :l :localize

      private
        MISSING_TRANSLATION = Object.new
        private_constant :MISSING_TRANSLATION

        def scope_key_by_partial(key)
          stringified_key = key.to_s
          if stringified_key.first == "."
            if @virtual_path
              @_scope_key_by_partial_cache ||= {}
              @_scope_key_by_partial_cache[@virtual_path] ||= @virtual_path.gsub(%r{/_?}, ".")
              "#{@_scope_key_by_partial_cache[@virtual_path]}#{stringified_key}"
            else
              raise "Cannot use t(#{key.inspect}) shortcut because path is not available"
            end
          else
            key
          end
        end

        def html_safe_translation_key?(key)
          /(?:_|\b)html\z/.match?(key.to_s)
        end
    end
  end
end
