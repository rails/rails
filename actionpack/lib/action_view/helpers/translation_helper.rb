require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers
    module TranslationHelper
      # Delegates to I18n#translate but also performs three additional functions. First, it'll catch MissingTranslationData exceptions 
      # and turn them into inline spans that contains the missing key, such that you can see in a view what is missing where.
      #
      # Second, it'll scope the key by the current partial if the key starts with a period. So if you call translate(".foo") from the
      # people/index.html.erb template, you'll actually be calling I18n.translate("people.index.foo"). This makes it less repetitive
      # to translate many keys within the same partials and gives you a simple framework for scoping them consistently. If you don't
      # prepend the key with a period, nothing is converted.
      #
      # Third, it’ll mark the translation as safe HTML if the key has the suffix "_html" or the last element of the key is the word 
      # "html". For example, calling translate("footer_html") or translate("footer.html") will return a safe HTML string that won’t 
      # be escaped by other HTML helper methods. This naming convention helps to identify translations that include HTML tags so that 
      # you know what kind of output to expect when you call translate in a template.

      def translate(key, options = {})
        options[:raise] = true
        translation = I18n.translate(scope_key_by_partial(key), options)
        translation = (translation.respond_to?(:join) ? translation.join : translation)
        if html_safe_translation_key? key
          translation.html_safe
        else
          translation
        end
      rescue I18n::MissingTranslationData => e
        keys = I18n.normalize_keys(e.locale, e.key, e.options[:scope])
        content_tag('span', keys.join(', '), :class => 'translation_missing')
      end
      alias :t :translate

      # Delegates to I18n.localize with no additional functionality.
      def localize(*args)
        I18n.localize(*args)
      end
      alias :l :localize

      private
        
        def scope_key_by_partial(key)
          strkey = key.respond_to?(:join) ? key.join : key.to_s
          if strkey.first == "."
            if @_virtual_path
              @_virtual_path.gsub(%r{/_?}, ".") + strkey
            else
              raise "Cannot use t(#{key.inspect}) shortcut because path is not available"
            end
          else
            key
          end
        end

        def html_safe_translation_key?(key)
          last_key = if key.is_a? Array
            key.last
          else
            key.to_s.split('.').last
          end
          (last_key == "html") || (last_key.ends_with? "_html")
        end
    end
  end
end
