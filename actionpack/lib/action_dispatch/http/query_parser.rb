# frozen_string_literal: true

require "uri"

module ActionDispatch
  class QueryParser
    DEFAULT_SEP = /& */n
    COMMON_SEP = { ";" => /; */n, ";," => /[;,] */n, "&" => /& */n }

    #--
    # Note this departs from WHATWG's specified parsing algorithm by
    # giving a nil value for keys that do not use '='. Callers that need
    # the standard's interpretation can use `v.to_s`.
    def self.each_pair(s, separator = nil)
      return enum_for(:each_pair, s, separator) unless block_given?

      (s || "").split(separator ? (COMMON_SEP[separator] || /[#{separator}] */n) : DEFAULT_SEP).each do |part|
        next if part.empty?

        k, v = part.split("=", 2)

        k = URI.decode_www_form_component(k)
        v &&= URI.decode_www_form_component(v)

        yield k, v
      end

      nil
    end

    # Converts a list of pairs to a single-depth hash. Pair names have
    # no structure, and map directly to hash keys. If a name occurs more
    # than once, the hash value will be an array, otherwise the value
    # will be a string or nil.
    #--
    # Note that for compatibility, while a nil value will be added to
    # the result hash, leading nils for a repeating name will _not_ be
    # preserved; the first non-nil value will overwrite the existing
    # entry, and only further repetition (including following nils) will
    # trigger an array conversion.
    def self.expand_simple_hash(pairs, hash = nil)
      # XXX: Do we need this?
      hash ||= {}

      pairs.each do |k, v|
        if current = hash[k]
          if Array == current.class
            current << v
          else
            hash[k] = [current, v]
          end
        else
          hash[k] = v
        end
      end
    end
  end
end
