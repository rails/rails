# encoding: utf-8

# EXPERIMENTAL
#
# The cascade module adds the ability to do cascading lookups to backends that
# are compatible to the Simple backend.
#
# By cascading lookups we mean that for any key that can not be found the
# Cascade module strips one segment off the scope part of the key and then
# tries to look up the key in that scope.
#
# E.g. when a lookup for the key :"foo.bar.baz" does not yield a result then
# the segment :bar will be stripped off the scope part :"foo.bar" and the new
# scope :foo will be used to look up the key :baz. If that does not succeed
# then the remaining scope segment :foo will be omitted, too, and again the
# key :baz will be looked up (now with no scope).
#
# Defaults will only kick in after the cascading lookups haven't succeeded.
#
# This behavior is useful for libraries like ActiveRecord validations where
# the library wants to give users a bunch of more or less fine-grained options
# of scopes for a particular key.
#
# Thanks to Clemens Kofler for the initial idea and implementation! See
# http://github.com/clemens/i18n-cascading-backend

module I18n
  @@fallbacks = nil

  module Backend
    module Cascade
      def lookup(locale, key, scope = [], separator = nil)
        return unless key
        locale, *scope = I18n.send(:normalize_translation_keys, locale, key, scope, separator)
        key = scope.pop

        begin
          result = super
          return result unless result.nil?
        end while scope.pop
      end
    end
  end
end
