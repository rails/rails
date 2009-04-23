unless '1.9'.respond_to?(:each_char)
  class String
    # Yields a single-character string for each character in the string.
    # When $KCODE = 'UTF8', multi-byte characters are yielded appropriately.
    def each_char
      require 'strscan' unless defined? ::StringScanner
      scanner, char = ::StringScanner.new(self), /./mu
      while c = scanner.scan(char)
        yield c
      end
    end
  end
end
