# encoding: utf-8

module I18n
  module Gettext
    PLURAL_SEPARATOR  = "\001"
    CONTEXT_SEPARATOR = "\004"

    @@plural_keys = { :en => [:one, :other] }

    class << self
      # returns an array of plural keys for the given locale so that we can
      # convert from gettext's integer-index based style
      # TODO move this information to the pluralization module
      def plural_keys(locale)
        @@plural_keys[locale] || @@plural_keys[:en]
      end

      def extract_scope(msgid, separator)
        scope = msgid.to_s.split(separator)
        msgid = scope.pop
        [scope, msgid]
      end
    end
  end
end
