require 'action_view/helpers/tag_helper'
require 'i18n/exceptions'

module ActionView
  # = Action View Translation Helpers
  module Helpers
    module TranslationHelper
      include TagHelper
      # Delegates to <tt>I18n#translate</tt> but also performs three additional functions.
      #
      # First, it will ensure that any thrown +MissingTranslation+ messages will be turned 
      # into inline spans that:
      #
      #   * have a "translation-missing" class set,
      #   * contain the missing key as a title attribute and
      #   * a titleized version of the last key segment as a text.
      #
      # E.g. the value returned for a missing translation key :"blog.post.title" will be
      # <span class="translation_missing" title="translation missing: en.blog.post.title">Title</span>.
      # This way your views will display rather reasonable strings but it will still
      # be easy to spot missing translations.
      #
      # Second, it'll scope the key by the current partial if the key starts
      # with a period. So if you call <tt>translate(".foo")</tt> from the
      # <tt>people/index.html.erb</tt> template, you'll actually be calling
      # <tt>I18n.translate("people.index.foo")</tt>. This makes it less repetitive
      # to translate many keys within the same partials and gives you a simple framework
      # for scoping them consistently. If you don't prepend the key with a period,
      # nothing is converted.
      #
      # Third, it'll mark the translation as safe HTML if the key has the suffix
      # "_html" or the last element of the key is the word "html". For example,
      # calling translate("footer_html") or translate("footer.html") will return
      # a safe HTML string that won't be escaped by other HTML helper methods. This
      # naming convention helps to identify translations that include HTML tags so that
      # you know what kind of output to expect when you call translate in a template.
      def translate(key, options = {})
        options[:default] = wrap_translate_defaults(options[:default]) if options[:default]

        # If the user has specified rescue_format then pass it all through, otherwise use
        # raise and do the work ourselves
        options[:raise] ||= ActionView::Base.raise_on_missing_translations

        raise_error = options[:raise] || options.key?(:rescue_format)
        unless raise_error
          options[:raise] = true
        end

        if html_safe_translation_key?(key)
          html_safe_options = options.dup
          options.except(*I18n::RESERVED_KEYS).each do |name, value|
            unless name == :count && value.is_a?(Numeric)
              html_safe_options[name] = ERB::Util.html_escape(value.to_s)
            end
          end
          translation = I18n.translate(scope_key_by_partial(key), html_safe_options)

          translation.respond_to?(:html_safe) ? translation.html_safe : translation
        else
          I18n.translate(scope_key_by_partial(key), options)
        end
      rescue I18n::MissingTranslationData => e
        raise e if raise_error

        keys = I18n.normalize_keys(e.locale, e.key, e.options[:scope])
        content_tag('span', keys.last.to_s.titleize, :class => 'translation_missing', :title => "translation missing: #{keys.join('.')}")
      end
      alias :t :translate

      # Delegates to <tt>I18n.localize</tt> with no additional functionality.
      #
      # See http://rubydoc.info/github/svenfuchs/i18n/master/I18n/Backend/Base:localize
      # for more information.
      def localize(*args)
        I18n.localize(*args)
      end
      alias :l :localize

      private
        def scope_key_by_partial(key)
          if key.to_s.first == "."
            if @virtual_path
              @virtual_path.gsub(%r{/_?}, ".") + key.to_s
            else
              raise "Cannot use t(#{key.inspect}) shortcut because path is not available"
            end
          else
            key
          end
        end

        def html_safe_translation_key?(key)
          key.to_s =~ /(\b|_|\.)html$/
        end

        def wrap_translate_defaults(defaults)
          new_defaults = []
          defaults     = Array(defaults)
          while key = defaults.shift
            if key.is_a?(Symbol)
              new_defaults << lambda { |_, options| translate key, options.merge(:default => defaults) }
              break
            else
              new_defaults << key
            end
          end

          new_defaults
        end
    end
  end
end
