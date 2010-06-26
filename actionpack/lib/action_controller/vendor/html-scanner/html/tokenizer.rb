require 'strscan'

module HTML #:nodoc:
  
  # A simple HTML tokenizer. It simply breaks a stream of text into tokens, where each
  # token is a string. Each string represents either "text", or an HTML element.
  #
  # This currently assumes valid XHTML, which means no free < or > characters.
  #
  # Usage:
  #
  #   tokenizer = HTML::Tokenizer.new(text)
  #   while token = tokenizer.next
  #     p token
  #   end
  class Tokenizer #:nodoc:
    
    # The current (byte) position in the text
    attr_reader :position
    
    # The current line number
    attr_reader :line
    
    # Create a new Tokenizer for the given text.
    def initialize(text)
      text.encode! if text.encoding_aware?
      @scanner = StringScanner.new(text)
      @position = 0
      @line = 0
      @current_line = 1
    end

    # Return the next token in the sequence, or +nil+ if there are no more tokens in
    # the stream.
    def next
      return nil if @scanner.eos?
      @position = @scanner.pos
      @line = @current_line
      if @scanner.check(/<\S/)
        update_current_line(scan_tag)
      else
        update_current_line(scan_text)
      end
    end
  
    private

      # Treat the text at the current position as a tag, and scan it. Supports
      # comments, doctype tags, and regular tags, and ignores less-than and
      # greater-than characters within quoted strings.
      def scan_tag
        tag = @scanner.getch
        if @scanner.scan(/!--/) # comment
          tag << @scanner.matched
          tag << (@scanner.scan_until(/--\s*>/) || @scanner.scan_until(/\Z/))
        elsif @scanner.scan(/!\[CDATA\[/)
          tag << @scanner.matched
          tag << (@scanner.scan_until(/\]\]>/) || @scanner.scan_until(/\Z/))
        elsif @scanner.scan(/!/) # doctype
          tag << @scanner.matched
          tag << consume_quoted_regions
        else
          tag << consume_quoted_regions
        end
        tag
      end

      # Scan all text up to the next < character and return it.
      def scan_text
        "#{@scanner.getch}#{@scanner.scan(/[^<]*/)}"
      end
      
      # Counts the number of newlines in the text and updates the current line
      # accordingly.
      def update_current_line(text)
        text.scan(/\r?\n/) { @current_line += 1 }
      end
      
      # Skips over quoted strings, so that less-than and greater-than characters
      # within the strings are ignored.
      def consume_quoted_regions
        text = ""
        loop do
          match = @scanner.scan_until(/['"<>]/) or break

          delim = @scanner.matched
          if delim == "<"
            match = match.chop
            @scanner.pos -= 1
          end

          text << match
          break if delim == "<" || delim == ">"

          # consume the quoted region
          while match = @scanner.scan_until(/[\\#{delim}]/)
            text << match
            break if @scanner.matched == delim
            break if @scanner.eos?
            text << @scanner.getch # skip the escaped character
          end
        end
        text
      end
  end
  
end
