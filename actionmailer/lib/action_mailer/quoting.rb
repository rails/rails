module ActionMailer
  module Quoting #:nodoc:
    # Convert the given text into quoted printable format, with an instruction
    # that the text be eventually interpreted in the given charset.
    def quoted_printable(text, charset)
      text = text.gsub( /[^a-z ]/i ) { quoted_printable_encode($&) }.
                  gsub( / /, "_" )
      "=?#{charset}?Q?#{text}?="
    end

    # Convert the given character to quoted printable format, taking into
    # account multi-byte characters (if executing with $KCODE="u", for instance)
    def quoted_printable_encode(character)
      result = ""
      character.each_byte { |b| result << "=%02x" % b }
      result
    end

    # A quick-and-dirty regexp for determining whether a string contains any
    # characters that need escaping.
    if !defined?(CHARS_NEEDING_QUOTING)
      CHARS_NEEDING_QUOTING = /[\000-\011\013\014\016-\037\177-\377]/
    end

    # Quote the given text if it contains any "illegal" characters
    def quote_if_necessary(text, charset)
      text = text.dup.force_encoding(Encoding::ASCII_8BIT) if text.respond_to?(:force_encoding)

      (text =~ CHARS_NEEDING_QUOTING) ?
        quoted_printable(text, charset) :
        text
    end

    # Quote any of the given strings if they contain any "illegal" characters
    def quote_any_if_necessary(charset, *args)
      args.map { |v| quote_if_necessary(v, charset) }
    end

    # Quote the given address if it needs to be. The address may be a
    # regular email address, or it can be a phrase followed by an address in
    # brackets. The phrase is the only part that will be quoted, and only if
    # it needs to be. This allows extended characters to be used in the
    # "to", "from", "cc", "bcc" and "reply-to" headers.
    def quote_address_if_necessary(address, charset)
      if Array === address
        address.map { |a| quote_address_if_necessary(a, charset) }
      elsif address =~ /^(\S.*)\s+(<.*>)$/
        address = $2
        phrase = quote_if_necessary($1.gsub(/^['"](.*)['"]$/, '\1'), charset)
        "\"#{phrase}\" #{address}"
      else
        address
      end
    end

    # Quote any of the given addresses, if they need to be.
    def quote_any_address_if_necessary(charset, *args)
      args.map { |v| quote_address_if_necessary(v, charset) }
    end
  end
end
