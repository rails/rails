#--
# Text::Format for Ruby
# Version 0.63
#
# Copyright (c) 2002 - 2003 Austin Ziegler
#
# $Id: format.rb,v 1.1.1.1 2004/10/14 11:59:57 webster132 Exp $
#
# ==========================================================================
# Revision History ::
# YYYY.MM.DD  Change ID   Developer
#             Description
# --------------------------------------------------------------------------
# 2002.10.18              Austin Ziegler
#             Fixed a minor problem with tabs not being counted. Changed
#             abbreviations from Hash to Array to better suit Ruby's
#             capabilities. Fixed problems with the way that Array arguments
#             are handled in calls to the major object types, excepting in
#             Text::Format#expand and Text::Format#unexpand (these will
#             probably need to be fixed).
# 2002.10.30              Austin Ziegler
#             Fixed the ordering of the <=> for binary tests. Fixed
#             Text::Format#expand and Text::Format#unexpand to handle array
#             arguments better.
# 2003.01.24              Austin Ziegler
#             Fixed a problem with Text::Format::RIGHT_FILL handling where a
#             single word is larger than #columns. Removed Comparable
#             capabilities (<=> doesn't make sense; == does). Added Symbol
#             equivalents for the Hash initialization. Hash initialization has
#             been modified so that values are set as follows (Symbols are
#             highest priority; strings are middle; defaults are lowest):
#                 @columns = arg[:columns] || arg['columns'] || @columns
#             Added #hard_margins, #split_rules, #hyphenator, and #split_words.
# 2003.02.07              Austin Ziegler
#             Fixed the installer for proper case-sensitive handling.
# 2003.03.28              Austin Ziegler
#             Added the ability for a hyphenator to receive the formatter
#             object. Fixed a bug for strings matching /\A\s*\Z/ failing
#             entirely. Fixed a test case failing under 1.6.8. 
# 2003.04.04              Austin Ziegler
#             Handle the case of hyphenators returning nil for first/rest.
# 2003.09.17          Austin Ziegler
#             Fixed a problem where #paragraphs(" ") was raising
#             NoMethodError.
#
# ==========================================================================
#++

module Text #:nodoc:
   # Text::Format for Ruby is copyright 2002 - 2005 by Austin Ziegler. It
   # is available under Ruby's licence, the Perl Artistic licence, or the
   # GNU GPL version 2 (or at your option, any later version). As a
   # special exception, for use with official Rails (provided by the
   # rubyonrails.org development team) and any project created with
   # official Rails, the following alternative MIT-style licence may be
   # used:
   #
   # == Text::Format Licence for Rails and Rails Applications
   # Permission is hereby granted, free of charge, to any person
   # obtaining a copy of this software and associated documentation files
   # (the "Software"), to deal in the Software without restriction,
   # including without limitation the rights to use, copy, modify, merge,
   # publish, distribute, sublicense, and/or sell copies of the Software,
   # and to permit persons to whom the Software is furnished to do so,
   # subject to the following conditions:
   #
   # * The names of its contributors may not be used to endorse or
   #   promote products derived from this software without specific prior
   #   written permission.
   #
   # The above copyright notice and this permission notice shall be
   # included in all copies or substantial portions of the Software.
   #
   # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   # EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   # MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   # NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   # BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   # ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   # CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   # SOFTWARE.  
   class Format
    VERSION = '0.63'

      # Local abbreviations. More can be added with Text::Format.abbreviations
    ABBREV = [ 'Mr', 'Mrs', 'Ms', 'Jr', 'Sr' ]

      # Formatting values
    LEFT_ALIGN  = 0
    RIGHT_ALIGN = 1
    RIGHT_FILL  = 2
    JUSTIFY     = 3

      # Word split modes (only applies when #hard_margins is true).
    SPLIT_FIXED                     = 1
    SPLIT_CONTINUATION              = 2
    SPLIT_HYPHENATION               = 4
    SPLIT_CONTINUATION_FIXED        = SPLIT_CONTINUATION | SPLIT_FIXED
    SPLIT_HYPHENATION_FIXED         = SPLIT_HYPHENATION | SPLIT_FIXED
    SPLIT_HYPHENATION_CONTINUATION  = SPLIT_HYPHENATION | SPLIT_CONTINUATION
    SPLIT_ALL                       = SPLIT_HYPHENATION | SPLIT_CONTINUATION | SPLIT_FIXED

      # Words forcibly split by Text::Format will be stored as split words.
      # This class represents a word forcibly split.
    class SplitWord
        # The word that was split.
      attr_reader :word
        # The first part of the word that was split.
      attr_reader :first
        # The remainder of the word that was split.
      attr_reader :rest

      def initialize(word, first, rest) #:nodoc:
        @word = word
        @first = first
        @rest = rest
      end
    end

  private
    LEQ_RE = /[.?!]['"]?$/

    def brk_re(i) #:nodoc:
      %r/((?:\S+\s+){#{i}})(.+)/
    end

    def posint(p) #:nodoc:
      p.to_i.abs
    end

  public
      # Compares two Text::Format objects. All settings of the objects are
      # compared *except* #hyphenator. Generated results (e.g., #split_words)
      # are not compared, either.
    def ==(o)
      (@text          ==  o.text)           &&
      (@columns       ==  o.columns)        &&
      (@left_margin   ==  o.left_margin)    &&
      (@right_margin  ==  o.right_margin)   &&
      (@hard_margins  ==  o.hard_margins)   &&
      (@split_rules   ==  o.split_rules)    &&
      (@first_indent  ==  o.first_indent)   &&
      (@body_indent   ==  o.body_indent)    &&
      (@tag_text      ==  o.tag_text)       &&
      (@tabstop       ==  o.tabstop)        &&
      (@format_style  ==  o.format_style)   &&
      (@extra_space   ==  o.extra_space)    &&
      (@tag_paragraph ==  o.tag_paragraph)  &&
      (@nobreak       ==  o.nobreak)        &&
      (@abbreviations ==  o.abbreviations)  &&
      (@nobreak_regex ==  o.nobreak_regex)
    end

      # The text to be manipulated. Note that value is optional, but if the
      # formatting functions are called without values, this text is what will
      # be formatted.
      #
      # *Default*::       <tt>[]</tt>
      # <b>Used in</b>::  All methods
    attr_accessor :text

      # The total width of the format area. The margins, indentation, and text
      # are formatted into this space.
      #
      #                             COLUMNS
      #  <-------------------------------------------------------------->
      #  <-----------><------><---------------------------><------------>
      #   left margin  indent  text is formatted into here  right margin
      #
      # *Default*::       <tt>72</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>,
      #                   <tt>#center</tt>
    attr_reader :columns

      # The total width of the format area. The margins, indentation, and text
      # are formatted into this space. The value provided is silently
      # converted to a positive integer.
      #
      #                             COLUMNS
      #  <-------------------------------------------------------------->
      #  <-----------><------><---------------------------><------------>
      #   left margin  indent  text is formatted into here  right margin
      #
      # *Default*::       <tt>72</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>,
      #                   <tt>#center</tt>
    def columns=(c)
      @columns = posint(c)
    end

      # The number of spaces used for the left margin.
      #
      #                             columns
      #  <-------------------------------------------------------------->
      #  <-----------><------><---------------------------><------------>
      #   LEFT MARGIN  indent  text is formatted into here  right margin
      #
      # *Default*::       <tt>0</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>,
      #                   <tt>#center</tt>
    attr_reader :left_margin

      # The number of spaces used for the left margin. The value provided is
      # silently converted to a positive integer value.
      #
      #                             columns
      #  <-------------------------------------------------------------->
      #  <-----------><------><---------------------------><------------>
      #   LEFT MARGIN  indent  text is formatted into here  right margin
      #
      # *Default*::       <tt>0</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>,
      #                   <tt>#center</tt>
    def left_margin=(left)
      @left_margin = posint(left)
    end

      # The number of spaces used for the right margin.
      #
      #                             columns
      #  <-------------------------------------------------------------->
      #  <-----------><------><---------------------------><------------>
      #   left margin  indent  text is formatted into here  RIGHT MARGIN
      #
      # *Default*::       <tt>0</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>,
      #                   <tt>#center</tt>
    attr_reader :right_margin

      # The number of spaces used for the right margin. The value provided is
      # silently converted to a positive integer value.
      #
      #                             columns
      #  <-------------------------------------------------------------->
      #  <-----------><------><---------------------------><------------>
      #   left margin  indent  text is formatted into here  RIGHT MARGIN
      #
      # *Default*::       <tt>0</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>,
      #                   <tt>#center</tt>
    def right_margin=(r)
      @right_margin = posint(r)
    end

      # The number of spaces to indent the first line of a paragraph.
      #
      #                             columns
      #  <-------------------------------------------------------------->
      #  <-----------><------><---------------------------><------------>
      #   left margin  INDENT  text is formatted into here  right margin
      #
      # *Default*::       <tt>4</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    attr_reader :first_indent

      # The number of spaces to indent the first line of a paragraph. The
      # value provided is silently converted to a positive integer value.
      #
      #                             columns
      #  <-------------------------------------------------------------->
      #  <-----------><------><---------------------------><------------>
      #   left margin  INDENT  text is formatted into here  right margin
      #
      # *Default*::       <tt>4</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    def first_indent=(f)
      @first_indent = posint(f)
    end

      # The number of spaces to indent all lines after the first line of a
      # paragraph.
      #
      #                             columns
      #  <-------------------------------------------------------------->
      #  <-----------><------><---------------------------><------------>
      #   left margin  INDENT  text is formatted into here  right margin
      #
      # *Default*::       <tt>0</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
  attr_reader :body_indent

      # The number of spaces to indent all lines after the first line of
      # a paragraph. The value provided is silently converted to a
      # positive integer value.
      #
      #                             columns
      #  <-------------------------------------------------------------->
      #  <-----------><------><---------------------------><------------>
      #   left margin  INDENT  text is formatted into here  right margin
      #
      # *Default*::       <tt>0</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    def body_indent=(b)
      @body_indent = posint(b)
    end

      # Normally, words larger than the format area will be placed on a line
      # by themselves. Setting this to +true+ will force words larger than the
      # format area to be split into one or more "words" each at most the size
      # of the format area. The first line and the original word will be
      # placed into <tt>#split_words</tt>. Note that this will cause the
      # output to look *similar* to a #format_style of JUSTIFY. (Lines will be
      # filled as much as possible.)
      #
      # *Default*::       +false+
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    attr_accessor :hard_margins

      # An array of words split during formatting if #hard_margins is set to
      # +true+.
      #   #split_words << Text::Format::SplitWord.new(word, first, rest)
    attr_reader :split_words

      # The object responsible for hyphenating. It must respond to
      # #hyphenate_to(word, size) or #hyphenate_to(word, size, formatter) and
      # return an array of the word split into two parts; if there is a
      # hyphenation mark to be applied, responsibility belongs to the
      # hyphenator object. The size is the MAXIMUM size permitted, including
      # any hyphenation marks. If the #hyphenate_to method has an arity of 3,
      # the formatter will be provided to the method. This allows the
      # hyphenator to make decisions about the hyphenation based on the
      # formatting rules.
      #
      # *Default*::       +nil+
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    attr_reader :hyphenator

      # The object responsible for hyphenating. It must respond to
      # #hyphenate_to(word, size) and return an array of the word hyphenated
      # into two parts. The size is the MAXIMUM size permitted, including any
      # hyphenation marks.
      #
      # *Default*::       +nil+
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    def hyphenator=(h)
      raise ArgumentError, "#{h.inspect} is not a valid hyphenator." unless h.respond_to?(:hyphenate_to)
      arity = h.method(:hyphenate_to).arity
      raise ArgumentError, "#{h.inspect} must have exactly two or three arguments." unless [2, 3].include?(arity)
      @hyphenator = h
      @hyphenator_arity = arity
    end

      # Specifies the split mode; used only when #hard_margins is set to
      # +true+. Allowable values are:
      # [+SPLIT_FIXED+]         The word will be split at the number of
      #                         characters needed, with no marking at all.
      #      repre
      #      senta
      #      ion
      # [+SPLIT_CONTINUATION+]  The word will be split at the number of
      #                         characters needed, with a C-style continuation
      #                         character. If a word is the only item on a
      #                         line and it cannot be split into an
      #                         appropriate size, SPLIT_FIXED will be used.
      #       repr\
      #       esen\
      #       tati\
      #       on
      # [+SPLIT_HYPHENATION+]   The word will be split according to the
      #                         hyphenator specified in #hyphenator. If there
      #                         is no #hyphenator specified, works like
      #                         SPLIT_CONTINUATION. The example is using
      #                         TeX::Hyphen. If a word is the only item on a
      #                         line and it cannot be split into an
      #                         appropriate size, SPLIT_CONTINUATION mode will
      #                         be used.
      #       rep-
      #       re-
      #       sen-
      #       ta-
      #       tion
      #
      # *Default*::       <tt>Text::Format::SPLIT_FIXED</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    attr_reader :split_rules

      # Specifies the split mode; used only when #hard_margins is set to
      # +true+. Allowable values are:
      # [+SPLIT_FIXED+]         The word will be split at the number of
      #                         characters needed, with no marking at all.
      #      repre
      #      senta
      #      ion
      # [+SPLIT_CONTINUATION+]  The word will be split at the number of
      #                         characters needed, with a C-style continuation
      #                         character.
      #       repr\
      #       esen\
      #       tati\
      #       on
      # [+SPLIT_HYPHENATION+]   The word will be split according to the
      #                         hyphenator specified in #hyphenator. If there
      #                         is no #hyphenator specified, works like
      #                         SPLIT_CONTINUATION. The example is using
      #                         TeX::Hyphen as the #hyphenator.
      #       rep-
      #       re-
      #       sen-
      #       ta-
      #       tion
      #
      # These values can be bitwise ORed together (e.g., <tt>SPLIT_FIXED |
      # SPLIT_CONTINUATION</tt>) to provide fallback split methods. In the
      # example given, an attempt will be made to split the word using the
      # rules of SPLIT_CONTINUATION; if there is not enough room, the word
      # will be split with the rules of SPLIT_FIXED. These combinations are
      # also available as the following values:
      # * +SPLIT_CONTINUATION_FIXED+
      # * +SPLIT_HYPHENATION_FIXED+
      # * +SPLIT_HYPHENATION_CONTINUATION+
      # * +SPLIT_ALL+
      #
      # *Default*::       <tt>Text::Format::SPLIT_FIXED</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    def split_rules=(s)
      raise ArgumentError, "Invalid value provided for split_rules." if ((s < SPLIT_FIXED) || (s > SPLIT_ALL))
      @split_rules = s
    end

      # Indicates whether sentence terminators should be followed by a single
      # space (+false+), or two spaces (+true+).
      #
      # *Default*::       +false+
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    attr_accessor :extra_space

      # Defines the current abbreviations as an array. This is only used if
      # extra_space is turned on.
      #
      # If one is abbreviating "President" as "Pres." (abbreviations =
      # ["Pres"]), then the results of formatting will be as illustrated in
      # the table below:
      #
      #       extra_space  |  include?        |  !include?
      #         true       |  Pres. Lincoln   |  Pres.  Lincoln
      #         false      |  Pres. Lincoln   |  Pres. Lincoln
      #
      # *Default*::       <tt>{}</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    attr_accessor :abbreviations

      # Indicates whether the formatting of paragraphs should be done with
      # tagged paragraphs. Useful only with <tt>#tag_text</tt>.
      #
      # *Default*::       +false+
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    attr_accessor :tag_paragraph

      # The array of text to be placed before each paragraph when
      # <tt>#tag_paragraph</tt> is +true+. When <tt>#format()</tt> is called,
      # only the first element of the array is used. When <tt>#paragraphs</tt>
      # is called, then each entry in the array will be used once, with
      # corresponding paragraphs. If the tag elements are exhausted before the
      # text is exhausted, then the remaining paragraphs will not be tagged.
      # Regardless of indentation settings, a blank line will be inserted
      # between all paragraphs when <tt>#tag_paragraph</tt> is +true+.
      #
      # *Default*::       <tt>[]</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    attr_accessor :tag_text

      # Indicates whether or not the non-breaking space feature should be
      # used.
      #
      # *Default*::       +false+
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    attr_accessor :nobreak

      # A hash which holds the regular expressions on which spaces should not
      # be broken. The hash is set up such that the key is the first word and
      # the value is the second word.
      #
      # For example, if +nobreak_regex+ contains the following hash:
      #
      #   { '^Mrs?\.$' => '\S+$', '^\S+$' => '^(?:S|J)r\.$'}
      #
      # Then "Mr. Jones", "Mrs. Jones", and "Jones Jr." would not be broken.
      # If this simple matching algorithm indicates that there should not be a
      # break at the current end of line, then a backtrack is done until there
      # are two words on which line breaking is permitted. If two such words
      # are not found, then the end of the line will be broken *regardless*.
      # If there is a single word on the current line, then no backtrack is
      # done and the word is stuck on the end.
      #
      # *Default*::       <tt>{}</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    attr_accessor :nobreak_regex

      # Indicates the number of spaces that a single tab represents.
      #
      # *Default*::       <tt>8</tt>
      # <b>Used in</b>::  <tt>#expand</tt>, <tt>#unexpand</tt>,
      #                   <tt>#paragraphs</tt>
    attr_reader :tabstop

      # Indicates the number of spaces that a single tab represents.
      #
      # *Default*::       <tt>8</tt>
      # <b>Used in</b>::  <tt>#expand</tt>, <tt>#unexpand</tt>,
      #                   <tt>#paragraphs</tt>
    def tabstop=(t)
      @tabstop = posint(t)
    end

      # Specifies the format style. Allowable values are:
      # [+LEFT_ALIGN+]    Left justified, ragged right.
      #      |A paragraph that is|
      #      |left aligned.|
      # [+RIGHT_ALIGN+]   Right justified, ragged left.
      #      |A paragraph that is|
      #      |     right aligned.|
      # [+RIGHT_FILL+]    Left justified, right ragged, filled to width by
      #                   spaces. (Essentially the same as +LEFT_ALIGN+ except
      #                   that lines are padded on the right.)
      #      |A paragraph that is|
      #      |left aligned.      |
      # [+JUSTIFY+]       Fully justified, words filled to width by spaces,
      #                   except the last line.
      #      |A paragraph  that|
      #      |is     justified.|
      #
      # *Default*::       <tt>Text::Format::LEFT_ALIGN</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    attr_reader :format_style

      # Specifies the format style. Allowable values are:
      # [+LEFT_ALIGN+]    Left justified, ragged right.
      #      |A paragraph that is|
      #      |left aligned.|
      # [+RIGHT_ALIGN+]   Right justified, ragged left.
      #      |A paragraph that is|
      #      |     right aligned.|
      # [+RIGHT_FILL+]    Left justified, right ragged, filled to width by
      #                   spaces. (Essentially the same as +LEFT_ALIGN+ except
      #                   that lines are padded on the right.)
      #      |A paragraph that is|
      #      |left aligned.      |
      # [+JUSTIFY+]       Fully justified, words filled to width by spaces.
      #      |A paragraph  that|
      #      |is     justified.|
      #
      # *Default*::       <tt>Text::Format::LEFT_ALIGN</tt>
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    def format_style=(fs)
      raise ArgumentError, "Invalid value provided for format_style." if ((fs < LEFT_ALIGN) || (fs > JUSTIFY))
      @format_style = fs
    end

      # Indicates that the format style is left alignment.
      #
      # *Default*::       +true+
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    def left_align?
      return @format_style == LEFT_ALIGN
    end

      # Indicates that the format style is right alignment.
      #
      # *Default*::       +false+
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    def right_align?
      return @format_style == RIGHT_ALIGN
    end

      # Indicates that the format style is right fill.
      #
      # *Default*::       +false+
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    def right_fill?
      return @format_style == RIGHT_FILL
    end

      # Indicates that the format style is full justification.
      #
      # *Default*::       +false+
      # <b>Used in</b>::  <tt>#format</tt>, <tt>#paragraphs</tt>
    def justify?
      return @format_style == JUSTIFY
    end

      # The default implementation of #hyphenate_to implements
      # SPLIT_CONTINUATION.
    def hyphenate_to(word, size)
      [word[0 .. (size - 2)] + "\\", word[(size - 1) .. -1]]
    end

  private
    def __do_split_word(word, size) #:nodoc:
      [word[0 .. (size - 1)], word[size .. -1]]
    end

    def __format(to_wrap) #:nodoc:
      words = to_wrap.split(/\s+/).compact
      words.shift if words[0].nil? or words[0].empty?
      to_wrap = []

      abbrev = false
      width = @columns - @first_indent - @left_margin - @right_margin
      indent_str = ' ' * @first_indent
      first_line = true
      line = words.shift
      abbrev = __is_abbrev(line) unless line.nil? || line.empty?

      while w = words.shift
        if (w.size + line.size < (width - 1)) ||
           ((line !~ LEQ_RE || abbrev) && (w.size + line.size < width))
          line << " " if (line =~ LEQ_RE) && (not abbrev)
          line << " #{w}"
        else
          line, w = __do_break(line, w) if @nobreak
          line, w = __do_hyphenate(line, w, width) if @hard_margins
          if w.index(/\s+/)
            w, *w2 = w.split(/\s+/)
            words.unshift(w2)
            words.flatten!
          end
          to_wrap << __make_line(line, indent_str, width, w.nil?) unless line.nil?
          if first_line
            first_line = false
            width = @columns - @body_indent - @left_margin - @right_margin
            indent_str = ' ' * @body_indent
          end
          line = w
        end

        abbrev = __is_abbrev(w) unless w.nil?
      end

      loop do
        break if line.nil? or line.empty?
        line, w = __do_hyphenate(line, w, width) if @hard_margins
        to_wrap << __make_line(line, indent_str, width, w.nil?)
        line = w
      end

      if (@tag_paragraph && (to_wrap.size > 0)) then
        clr = %r{`(\w+)'}.match([caller(1)].flatten[0])[1]
        clr = "" if clr.nil?

        if ((not @tag_text[0].nil?) && (@tag_cur.size < 1) &&
            (clr != "__paragraphs")) then
          @tag_cur = @tag_text[0]
        end

        fchar = /(\S)/.match(to_wrap[0])[1]
        white = to_wrap[0].index(fchar)
        if ((white - @left_margin - 1) > @tag_cur.size) then
          white = @tag_cur.size + @left_margin
          to_wrap[0].gsub!(/^ {#{white}}/, "#{' ' * @left_margin}#{@tag_cur}")
        else
          to_wrap.unshift("#{' ' * @left_margin}#{@tag_cur}\n")
        end
      end
      to_wrap.join('')
    end

      # format lines in text into paragraphs with each element of @wrap a
      # paragraph; uses Text::Format.format for the formatting
    def __paragraphs(to_wrap) #:nodoc:
      if ((@first_indent == @body_indent) || @tag_paragraph) then
        p_end = "\n"
      else
        p_end = ''
      end

      cnt = 0
      ret = []
      to_wrap.each do |tw|
        @tag_cur = @tag_text[cnt] if @tag_paragraph
        @tag_cur = '' if @tag_cur.nil?
        line = __format(tw)
        ret << "#{line}#{p_end}" if (not line.nil?) && (line.size > 0)
        cnt += 1
      end

      ret[-1].chomp! unless ret.empty?
      ret.join('')
    end

      # center text using spaces on left side to pad it out empty lines
      # are preserved
    def __center(to_center) #:nodoc:
      tabs = 0
      width = @columns - @left_margin - @right_margin
      centered = []
      to_center.each do |tc|
        s = tc.strip
        tabs = s.count("\t")
        tabs = 0 if tabs.nil?
        ct = ((width - s.size - (tabs * @tabstop) + tabs) / 2)
        ct = (width - @left_margin - @right_margin) - ct
        centered << "#{s.rjust(ct)}\n"
      end
      centered.join('')
    end

      # expand tabs to spaces should be similar to Text::Tabs::expand
    def __expand(to_expand) #:nodoc:
      expanded = []
      to_expand.split("\n").each { |te| expanded << te.gsub(/\t/, ' ' * @tabstop) }
      expanded.join('')
    end

    def __unexpand(to_unexpand) #:nodoc:
      unexpanded = []
      to_unexpand.split("\n").each { |tu| unexpanded << tu.gsub(/ {#{@tabstop}}/, "\t") }
      unexpanded.join('')
    end

    def __is_abbrev(word) #:nodoc:
        # remove period if there is one.
      w = word.gsub(/\.$/, '') unless word.nil?
      return true if (!@extra_space || ABBREV.include?(w) || @abbreviations.include?(w))
      false
    end

    def __make_line(line, indent, width, last = false) #:nodoc:
      lmargin = " " * @left_margin
      fill = " " * (width - line.size) if right_fill? && (line.size <= width)

      if (justify? && ((not line.nil?) && (not line.empty?)) && line =~ /\S+\s+\S+/ && !last)
        spaces = width - line.size
        words = line.split(/(\s+)/)
        ws = spaces / (words.size / 2)
        spaces = spaces % (words.size / 2) if ws > 0
        words.reverse.each do |rw|
          next if (rw =~ /^\S/)
          rw.sub!(/^/, " " * ws)
          next unless (spaces > 0)
          rw.sub!(/^/, " ")
          spaces -= 1
        end
        line = words.join('')
      end
      line = "#{lmargin}#{indent}#{line}#{fill}\n" unless line.nil?
      if right_align? && (not line.nil?)
        line.sub(/^/, " " * (@columns - @right_margin - (line.size - 1)))
      else
        line
      end
    end

    def __do_hyphenate(line, next_line, width) #:nodoc:
      rline = line.dup rescue line
      rnext = next_line.dup rescue next_line
      loop do
        if rline.size == width
          break
        elsif rline.size > width
          words = rline.strip.split(/\s+/)
          word = words[-1].dup
          size = width - rline.size + word.size
          if (size <= 0)
            words[-1] = nil
            rline = words.join(' ').strip
            rnext = "#{word} #{rnext}".strip
            next
          end

          first = rest = nil

          if ((@split_rules & SPLIT_HYPHENATION) != 0)
            if @hyphenator_arity == 2
              first, rest = @hyphenator.hyphenate_to(word, size)
            else
              first, rest = @hyphenator.hyphenate_to(word, size, self)
            end
          end

          if ((@split_rules & SPLIT_CONTINUATION) != 0) and first.nil?
            first, rest = self.hyphenate_to(word, size)
          end

          if ((@split_rules & SPLIT_FIXED) != 0) and first.nil?
            first.nil? or @split_rules == SPLIT_FIXED
            first, rest = __do_split_word(word, size)
          end

          if first.nil?
            words[-1] = nil
            rest = word
          else
            words[-1] = first
            @split_words << SplitWord.new(word, first, rest)
          end
          rline = words.join(' ').strip
          rnext = "#{rest} #{rnext}".strip
          break
        else
          break if rnext.nil? or rnext.empty? or rline.nil? or rline.empty?
          words = rnext.split(/\s+/)
          word = words.shift
          size = width - rline.size - 1

          if (size <= 0)
            rnext = "#{word} #{words.join(' ')}".strip
            break
          end

          first = rest = nil

          if ((@split_rules & SPLIT_HYPHENATION) != 0)
            if @hyphenator_arity == 2
              first, rest = @hyphenator.hyphenate_to(word, size)
            else
              first, rest = @hyphenator.hyphenate_to(word, size, self)
            end
          end

          first, rest = self.hyphenate_to(word, size) if ((@split_rules & SPLIT_CONTINUATION) != 0) and first.nil?

          first, rest = __do_split_word(word, size) if ((@split_rules & SPLIT_FIXED) != 0) and first.nil?

          if (rline.size + (first ? first.size : 0)) < width
            @split_words << SplitWord.new(word, first, rest)
            rline = "#{rline} #{first}".strip
            rnext = "#{rest} #{words.join(' ')}".strip
          end
          break
        end
      end
      [rline, rnext]
    end

    def __do_break(line, next_line) #:nodoc:
      no_brk = false
      words = []
      words = line.split(/\s+/) unless line.nil?
      last_word = words[-1]

      @nobreak_regex.each { |k, v| no_brk = ((last_word =~ /#{k}/) and (next_line =~ /#{v}/)) }

      if no_brk && words.size > 1
        i = words.size
        while i > 0
          no_brk = false
          @nobreak_regex.each { |k, v| no_brk = ((words[i + 1] =~ /#{k}/) && (words[i] =~ /#{v}/)) }
          i -= 1
          break if not no_brk
        end
        if i > 0
          l = brk_re(i).match(line)
          line.sub!(brk_re(i), l[1])
          next_line = "#{l[2]} #{next_line}"
          line.sub!(/\s+$/, '')
        end
      end
      [line, next_line]
    end

    def __create(arg = nil, &block) #:nodoc:
        # Format::Text.new(text-to-wrap)
      @text = arg unless arg.nil?
        # Defaults
      @columns          = 72
      @tabstop          = 8
      @first_indent     = 4
      @body_indent      = 0
      @format_style     = LEFT_ALIGN
      @left_margin      = 0
      @right_margin     = 0
      @extra_space      = false
      @text             = Array.new if @text.nil?
      @tag_paragraph    = false
      @tag_text         = Array.new
      @tag_cur          = ""
      @abbreviations    = Array.new
      @nobreak          = false
      @nobreak_regex    = Hash.new
      @split_words      = Array.new
      @hard_margins     = false
      @split_rules      = SPLIT_FIXED
      @hyphenator       = self
      @hyphenator_arity = self.method(:hyphenate_to).arity

      instance_eval(&block) unless block.nil?
    end

  public
      # Formats text into a nice paragraph format. The text is separated
      # into words and then reassembled a word at a time using the settings
      # of this Format object. If a word is larger than the number of
      # columns available for formatting, then that word will appear on the
      # line by itself.
      #
      # If +to_wrap+ is +nil+, then the value of <tt>#text</tt> will be
      # worked on.
    def format(to_wrap = nil)
      to_wrap = @text if to_wrap.nil?
      if to_wrap.class == Array
        __format(to_wrap[0])
      else
        __format(to_wrap)
      end
    end

      # Considers each element of text (provided or internal) as a paragraph.
      # If <tt>#first_indent</tt> is the same as <tt>#body_indent</tt>, then
      # paragraphs will be separated by a single empty line in the result;
      # otherwise, the paragraphs will follow immediately after each other.
      # Uses <tt>#format</tt> to do the heavy lifting.
    def paragraphs(to_wrap = nil)
      to_wrap = @text if to_wrap.nil?
      __paragraphs([to_wrap].flatten)
    end

      # Centers the text, preserving empty lines and tabs.
    def center(to_center = nil)
      to_center = @text if to_center.nil?
      __center([to_center].flatten)
    end

      # Replaces all tab characters in the text with <tt>#tabstop</tt> spaces.
    def expand(to_expand = nil)
      to_expand = @text if to_expand.nil?
      if to_expand.class == Array
        to_expand.collect { |te| __expand(te) }
      else
        __expand(to_expand)
      end
    end

      # Replaces all occurrences of <tt>#tabstop</tt> consecutive spaces
      # with a tab character.
    def unexpand(to_unexpand = nil)
      to_unexpand = @text if to_unexpand.nil?
      if to_unexpand.class == Array
        to_unexpand.collect { |te| v << __unexpand(te) }
      else
        __unexpand(to_unexpand)
      end
    end

      # This constructor takes advantage of a technique for Ruby object
      # construction introduced by Andy Hunt and Dave Thomas (see reference),
      # where optional values are set using commands in a block.
      #
      #   Text::Format.new {
      #       columns         = 72
      #       left_margin     = 0
      #       right_margin    = 0
      #       first_indent    = 4
      #       body_indent     = 0
      #       format_style    = Text::Format::LEFT_ALIGN
      #       extra_space     = false
      #       abbreviations   = {}
      #       tag_paragraph   = false
      #       tag_text        = []
      #       nobreak         = false
      #       nobreak_regex   = {}
      #       tabstop         = 8
      #       text            = nil
      #   }
      #
      # As shown above, +arg+ is optional. If +arg+ is specified and is a
      # +String+, then arg is used as the default value of <tt>#text</tt>.
      # Alternately, an existing Text::Format object can be used or a Hash can
      # be used. With all forms, a block can be specified.
      #
      # *Reference*:: "Object Construction and Blocks"
      #               <http://www.pragmaticprogrammer.com/ruby/articles/insteval.html>
      #
    def initialize(arg = nil, &block)
      case arg
      when Text::Format
        __create(arg.text) do
          @columns        = arg.columns
          @tabstop        = arg.tabstop
          @first_indent   = arg.first_indent
          @body_indent    = arg.body_indent
          @format_style   = arg.format_style
          @left_margin    = arg.left_margin
          @right_margin   = arg.right_margin
          @extra_space    = arg.extra_space
          @tag_paragraph  = arg.tag_paragraph
          @tag_text       = arg.tag_text
          @abbreviations  = arg.abbreviations
          @nobreak        = arg.nobreak
          @nobreak_regex  = arg.nobreak_regex
          @text           = arg.text
          @hard_margins   = arg.hard_margins
          @split_words    = arg.split_words
          @split_rules    = arg.split_rules
          @hyphenator     = arg.hyphenator
        end
        instance_eval(&block) unless block.nil?
      when Hash
        __create do
          @columns       = arg[:columns]       || arg['columns']       || @columns
          @tabstop       = arg[:tabstop]       || arg['tabstop']       || @tabstop
          @first_indent  = arg[:first_indent]  || arg['first_indent']  || @first_indent
          @body_indent   = arg[:body_indent]   || arg['body_indent']   || @body_indent
          @format_style  = arg[:format_style]  || arg['format_style']  || @format_style
          @left_margin   = arg[:left_margin]   || arg['left_margin']   || @left_margin
          @right_margin  = arg[:right_margin]  || arg['right_margin']  || @right_margin
          @extra_space   = arg[:extra_space]   || arg['extra_space']   || @extra_space
          @text          = arg[:text]          || arg['text']          || @text
          @tag_paragraph = arg[:tag_paragraph] || arg['tag_paragraph'] || @tag_paragraph
          @tag_text      = arg[:tag_text]      || arg['tag_text']      || @tag_text
          @abbreviations = arg[:abbreviations] || arg['abbreviations'] || @abbreviations
          @nobreak       = arg[:nobreak]       || arg['nobreak']       || @nobreak
          @nobreak_regex = arg[:nobreak_regex] || arg['nobreak_regex'] || @nobreak_regex
          @hard_margins  = arg[:hard_margins]  || arg['hard_margins']  || @hard_margins
          @split_rules   = arg[:split_rules] || arg['split_rules'] || @split_rules
          @hyphenator    = arg[:hyphenator] || arg['hyphenator'] || @hyphenator
        end
        instance_eval(&block) unless block.nil?
      when String
        __create(arg, &block)
      when NilClass
        __create(&block)
      else
        raise TypeError
      end
    end
  end
end

if __FILE__ == $0
  require 'test/unit'

  class TestText__Format < Test::Unit::TestCase #:nodoc:
    attr_accessor :format_o

    GETTYSBURG = <<-'EOS'
    Four score and seven years ago our fathers brought forth on this
    continent a new nation, conceived in liberty and dedicated to the
    proposition that all men are created equal. Now we are engaged in
    a great civil war, testing whether that nation or any nation so
    conceived and so dedicated can long endure. We are met on a great
    battlefield of that war. We have come to dedicate a portion of
    that field as a final resting-place for those who here gave their
    lives that that nation might live. It is altogether fitting and
    proper that we should do this. But in a larger sense, we cannot
    dedicate, we cannot consecrate, we cannot hallow this ground.
    The brave men, living and dead who struggled here have consecrated
    it far above our poor power to add or detract. The world will
    little note nor long remember what we say here, but it can never
    forget what they did here. It is for us the living rather to be
    dedicated here to the unfinished work which they who fought here
    have thus far so nobly advanced. It is rather for us to be here
    dedicated to the great task remaining before us--that from these
    honored dead we take increased devotion to that cause for which
    they gave the last full measure of devotion--that we here highly
    resolve that these dead shall not have died in vain, that this
    nation under God shall have a new birth of freedom, and that
    government of the people, by the people, for the people shall
    not perish from the earth.

            -- Pres. Abraham Lincoln, 19 November 1863
    EOS

    FIVE_COL = "Four \nscore\nand s\neven \nyears\nago o\nur fa\nthers\nbroug\nht fo\nrth o\nn thi\ns con\ntinen\nt a n\new na\ntion,\nconce\nived \nin li\nberty\nand d\nedica\nted t\no the\npropo\nsitio\nn tha\nt all\nmen a\nre cr\neated\nequal\n. Now\nwe ar\ne eng\naged \nin a \ngreat\ncivil\nwar, \ntesti\nng wh\nether\nthat \nnatio\nn or \nany n\nation\nso co\nnceiv\ned an\nd so \ndedic\nated \ncan l\nong e\nndure\n. We \nare m\net on\na gre\nat ba\nttlef\nield \nof th\nat wa\nr. We\nhave \ncome \nto de\ndicat\ne a p\nortio\nn of \nthat \nfield\nas a \nfinal\nresti\nng-pl\nace f\nor th\nose w\nho he\nre ga\nve th\neir l\nives \nthat \nthat \nnatio\nn mig\nht li\nve. I\nt is \naltog\nether\nfitti\nng an\nd pro\nper t\nhat w\ne sho\nuld d\no thi\ns. Bu\nt in \na lar\nger s\nense,\nwe ca\nnnot \ndedic\nate, \nwe ca\nnnot \nconse\ncrate\n, we \ncanno\nt hal\nlow t\nhis g\nround\n. The\nbrave\nmen, \nlivin\ng and\ndead \nwho s\ntrugg\nled h\nere h\nave c\nonsec\nrated\nit fa\nr abo\nve ou\nr poo\nr pow\ner to\nadd o\nr det\nract.\nThe w\norld \nwill \nlittl\ne not\ne nor\nlong \nremem\nber w\nhat w\ne say\nhere,\nbut i\nt can\nnever\nforge\nt wha\nt the\ny did\nhere.\nIt is\nfor u\ns the\nlivin\ng rat\nher t\no be \ndedic\nated \nhere \nto th\ne unf\ninish\ned wo\nrk wh\nich t\nhey w\nho fo\nught \nhere \nhave \nthus \nfar s\no nob\nly ad\nvance\nd. It\nis ra\nther \nfor u\ns to \nbe he\nre de\ndicat\ned to\nthe g\nreat \ntask \nremai\nning \nbefor\ne us-\n-that\nfrom \nthese\nhonor\ned de\nad we\ntake \nincre\nased \ndevot\nion t\no tha\nt cau\nse fo\nr whi\nch th\ney ga\nve th\ne las\nt ful\nl mea\nsure \nof de\nvotio\nn--th\nat we\nhere \nhighl\ny res\nolve \nthat \nthese\ndead \nshall\nnot h\nave d\nied i\nn vai\nn, th\nat th\nis na\ntion \nunder\nGod s\nhall \nhave \na new\nbirth\nof fr\needom\n, and\nthat \ngover\nnment\nof th\ne peo\nple, \nby th\ne peo\nple, \nfor t\nhe pe\nople \nshall\nnot p\nerish\nfrom \nthe e\narth.\n-- Pr\nes. A\nbraha\nm Lin\ncoln,\n19 No\nvembe\nr 186\n3    \n"

    FIVE_CNT = "Four \nscore\nand  \nseven\nyears\nago  \nour  \nfath\\\ners  \nbrou\\\nght  \nforth\non t\\\nhis  \ncont\\\ninent\na new\nnati\\\non,  \nconc\\\neived\nin l\\\niber\\\nty a\\\nnd d\\\nedic\\\nated \nto t\\\nhe p\\\nropo\\\nsiti\\\non t\\\nhat  \nall  \nmen  \nare  \ncrea\\\nted  \nequa\\\nl. N\\\now we\nare  \nenga\\\nged  \nin a \ngreat\ncivil\nwar, \ntest\\\ning  \nwhet\\\nher  \nthat \nnati\\\non or\nany  \nnati\\\non so\nconc\\\neived\nand  \nso d\\\nedic\\\nated \ncan  \nlong \nendu\\\nre.  \nWe a\\\nre m\\\net on\na gr\\\neat  \nbatt\\\nlefi\\\neld  \nof t\\\nhat  \nwar. \nWe h\\\nave  \ncome \nto d\\\nedic\\\nate a\nport\\\nion  \nof t\\\nhat  \nfield\nas a \nfinal\nrest\\\ning-\\\nplace\nfor  \nthose\nwho  \nhere \ngave \ntheir\nlives\nthat \nthat \nnati\\\non m\\\night \nlive.\nIt is\nalto\\\ngeth\\\ner f\\\nitti\\\nng a\\\nnd p\\\nroper\nthat \nwe s\\\nhould\ndo t\\\nhis. \nBut  \nin a \nlarg\\\ner s\\\nense,\nwe c\\\nannot\ndedi\\\ncate,\nwe c\\\nannot\ncons\\\necra\\\nte,  \nwe c\\\nannot\nhall\\\now t\\\nhis  \ngrou\\\nnd.  \nThe  \nbrave\nmen, \nlivi\\\nng a\\\nnd d\\\nead  \nwho  \nstru\\\nggled\nhere \nhave \ncons\\\necra\\\nted  \nit f\\\nar a\\\nbove \nour  \npoor \npower\nto a\\\ndd or\ndetr\\\nact. \nThe  \nworld\nwill \nlitt\\\nle n\\\note  \nnor  \nlong \nreme\\\nmber \nwhat \nwe s\\\nay h\\\nere, \nbut  \nit c\\\nan n\\\never \nforg\\\net w\\\nhat  \nthey \ndid  \nhere.\nIt is\nfor  \nus t\\\nhe l\\\niving\nrath\\\ner to\nbe d\\\nedic\\\nated \nhere \nto t\\\nhe u\\\nnfin\\\nished\nwork \nwhich\nthey \nwho  \nfoug\\\nht h\\\nere  \nhave \nthus \nfar  \nso n\\\nobly \nadva\\\nnced.\nIt is\nrath\\\ner f\\\nor us\nto be\nhere \ndedi\\\ncated\nto t\\\nhe g\\\nreat \ntask \nrema\\\nining\nbefo\\\nre u\\\ns--t\\\nhat  \nfrom \nthese\nhono\\\nred  \ndead \nwe t\\\nake  \nincr\\\neased\ndevo\\\ntion \nto t\\\nhat  \ncause\nfor  \nwhich\nthey \ngave \nthe  \nlast \nfull \nmeas\\\nure  \nof d\\\nevot\\\nion-\\\n-that\nwe h\\\nere  \nhigh\\\nly r\\\nesol\\\nve t\\\nhat  \nthese\ndead \nshall\nnot  \nhave \ndied \nin v\\\nain, \nthat \nthis \nnati\\\non u\\\nnder \nGod  \nshall\nhave \na new\nbirth\nof f\\\nreed\\\nom,  \nand  \nthat \ngove\\\nrnme\\\nnt of\nthe  \npeop\\\nle,  \nby t\\\nhe p\\\neopl\\\ne, f\\\nor t\\\nhe p\\\neople\nshall\nnot  \nperi\\\nsh f\\\nrom  \nthe  \neart\\\nh. --\nPres.\nAbra\\\nham  \nLinc\\\noln, \n19 N\\\novem\\\nber  \n1863 \n"

      # Tests both abbreviations and abbreviations=
    def test_abbreviations
      abbr = ["    Pres. Abraham Lincoln\n", "    Pres.  Abraham Lincoln\n"]
      assert_nothing_raised { @format_o = Text::Format.new }
      assert_equal([], @format_o.abbreviations)
      assert_nothing_raised { @format_o.abbreviations = [ 'foo', 'bar' ] }
      assert_equal([ 'foo', 'bar' ], @format_o.abbreviations)
      assert_equal(abbr[0], @format_o.format(abbr[0]))
      assert_nothing_raised { @format_o.extra_space = true }
      assert_equal(abbr[1], @format_o.format(abbr[0]))
      assert_nothing_raised { @format_o.abbreviations = [ "Pres" ] }
      assert_equal([ "Pres" ], @format_o.abbreviations)
      assert_equal(abbr[0], @format_o.format(abbr[0]))
      assert_nothing_raised { @format_o.extra_space = false }
      assert_equal(abbr[0], @format_o.format(abbr[0]))
    end

      # Tests both body_indent and body_indent=
    def test_body_indent
      assert_nothing_raised { @format_o = Text::Format.new }
      assert_equal(0, @format_o.body_indent)
      assert_nothing_raised { @format_o.body_indent = 7 }
      assert_equal(7, @format_o.body_indent)
      assert_nothing_raised { @format_o.body_indent = -3 }
      assert_equal(3, @format_o.body_indent)
      assert_nothing_raised { @format_o.body_indent = "9" }
      assert_equal(9, @format_o.body_indent)
      assert_nothing_raised { @format_o.body_indent = "-2" }
      assert_equal(2, @format_o.body_indent)
      assert_match(/^  [^ ]/, @format_o.format(GETTYSBURG).split("\n")[1])
    end

      # Tests both columns and columns=
    def test_columns
      assert_nothing_raised { @format_o = Text::Format.new }
      assert_equal(72, @format_o.columns)
      assert_nothing_raised { @format_o.columns = 7 }
      assert_equal(7, @format_o.columns)
      assert_nothing_raised { @format_o.columns = -3 }
      assert_equal(3, @format_o.columns)
      assert_nothing_raised { @format_o.columns = "9" }
      assert_equal(9, @format_o.columns)
      assert_nothing_raised { @format_o.columns = "-2" }
      assert_equal(2, @format_o.columns)
      assert_nothing_raised { @format_o.columns = 40 }
      assert_equal(40, @format_o.columns)
      assert_match(/this continent$/,
                   @format_o.format(GETTYSBURG).split("\n")[1])
    end

      # Tests both extra_space and extra_space=
    def test_extra_space
      assert_nothing_raised { @format_o = Text::Format.new }
      assert(!@format_o.extra_space)
      assert_nothing_raised { @format_o.extra_space = true }
      assert(@format_o.extra_space)
        # The behaviour of extra_space is tested in test_abbreviations. There
        # is no need to reproduce it here.
    end

      # Tests both first_indent and first_indent=
    def test_first_indent
      assert_nothing_raised { @format_o = Text::Format.new }
      assert_equal(4, @format_o.first_indent)
      assert_nothing_raised { @format_o.first_indent = 7 }
      assert_equal(7, @format_o.first_indent)
      assert_nothing_raised { @format_o.first_indent = -3 }
      assert_equal(3, @format_o.first_indent)
      assert_nothing_raised { @format_o.first_indent = "9" }
      assert_equal(9, @format_o.first_indent)
      assert_nothing_raised { @format_o.first_indent = "-2" }
      assert_equal(2, @format_o.first_indent)
      assert_match(/^  [^ ]/, @format_o.format(GETTYSBURG).split("\n")[0])
    end

    def test_format_style
      assert_nothing_raised { @format_o = Text::Format.new }
      assert_equal(Text::Format::LEFT_ALIGN, @format_o.format_style)
      assert_match(/^November 1863$/,
                   @format_o.format(GETTYSBURG).split("\n")[-1])
      assert_nothing_raised {
        @format_o.format_style = Text::Format::RIGHT_ALIGN
      }
      assert_equal(Text::Format::RIGHT_ALIGN, @format_o.format_style)
      assert_match(/^ +November 1863$/,
                   @format_o.format(GETTYSBURG).split("\n")[-1])
      assert_nothing_raised {
        @format_o.format_style = Text::Format::RIGHT_FILL
      }
      assert_equal(Text::Format::RIGHT_FILL, @format_o.format_style)
      assert_match(/^November 1863 +$/,
                   @format_o.format(GETTYSBURG).split("\n")[-1])
      assert_nothing_raised { @format_o.format_style = Text::Format::JUSTIFY }
      assert_equal(Text::Format::JUSTIFY, @format_o.format_style)
      assert_match(/^of freedom, and that government of the people, by the  people,  for  the$/,
                   @format_o.format(GETTYSBURG).split("\n")[-3])
      assert_raise(ArgumentError) { @format_o.format_style = 33 }
    end

    def test_tag_paragraph
      assert_nothing_raised { @format_o = Text::Format.new }
      assert(!@format_o.tag_paragraph)
      assert_nothing_raised { @format_o.tag_paragraph = true }
      assert(@format_o.tag_paragraph)
      assert_not_equal(@format_o.paragraphs([GETTYSBURG, GETTYSBURG]),
                       Text::Format.new.paragraphs([GETTYSBURG, GETTYSBURG]))
    end

    def test_tag_text
      assert_nothing_raised { @format_o = Text::Format.new }
      assert_equal([], @format_o.tag_text)
      assert_equal(@format_o.format(GETTYSBURG),
                   Text::Format.new.format(GETTYSBURG))
      assert_nothing_raised {
        @format_o.tag_paragraph = true
        @format_o.tag_text = ["Gettysburg Address", "---"]
      }
      assert_not_equal(@format_o.format(GETTYSBURG),
                       Text::Format.new.format(GETTYSBURG))
      assert_not_equal(@format_o.paragraphs([GETTYSBURG, GETTYSBURG]),
                       Text::Format.new.paragraphs([GETTYSBURG, GETTYSBURG]))
      assert_not_equal(@format_o.paragraphs([GETTYSBURG, GETTYSBURG,
                                             GETTYSBURG]),
                       Text::Format.new.paragraphs([GETTYSBURG, GETTYSBURG,
                                                    GETTYSBURG]))
    end

    def test_justify?
      assert_nothing_raised { @format_o = Text::Format.new }
      assert(!@format_o.justify?)
      assert_nothing_raised {
        @format_o.format_style = Text::Format::RIGHT_ALIGN
      }
      assert(!@format_o.justify?)
      assert_nothing_raised {
        @format_o.format_style = Text::Format::RIGHT_FILL
      }
      assert(!@format_o.justify?)
      assert_nothing_raised {
        @format_o.format_style = Text::Format::JUSTIFY
      }
      assert(@format_o.justify?)
        # The format testing is done in test_format_style
    end

    def test_left_align?
      assert_nothing_raised { @format_o = Text::Format.new }
      assert(@format_o.left_align?)
      assert_nothing_raised {
        @format_o.format_style = Text::Format::RIGHT_ALIGN
      }
      assert(!@format_o.left_align?)
      assert_nothing_raised {
        @format_o.format_style = Text::Format::RIGHT_FILL
      }
      assert(!@format_o.left_align?)
      assert_nothing_raised { @format_o.format_style = Text::Format::JUSTIFY }
      assert(!@format_o.left_align?)
        # The format testing is done in test_format_style
    end

    def test_left_margin
      assert_nothing_raised { @format_o = Text::Format.new }
      assert_equal(0, @format_o.left_margin)
      assert_nothing_raised { @format_o.left_margin = -3 }
      assert_equal(3, @format_o.left_margin)
      assert_nothing_raised { @format_o.left_margin = "9" }
      assert_equal(9, @format_o.left_margin)
      assert_nothing_raised { @format_o.left_margin = "-2" }
      assert_equal(2, @format_o.left_margin)
      assert_nothing_raised { @format_o.left_margin = 7 }
      assert_equal(7, @format_o.left_margin)
      assert_nothing_raised {
        ft = @format_o.format(GETTYSBURG).split("\n")
        assert_match(/^ {11}Four score/, ft[0])
        assert_match(/^ {7}November/, ft[-1])
      }
    end

    def test_hard_margins
      assert_nothing_raised { @format_o = Text::Format.new }
      assert(!@format_o.hard_margins)
      assert_nothing_raised {
        @format_o.hard_margins = true
        @format_o.columns = 5
        @format_o.first_indent = 0
        @format_o.format_style = Text::Format::RIGHT_FILL
      }
      assert(@format_o.hard_margins)
      assert_equal(FIVE_COL, @format_o.format(GETTYSBURG))
      assert_nothing_raised {
        @format_o.split_rules |= Text::Format::SPLIT_CONTINUATION
        assert_equal(Text::Format::SPLIT_CONTINUATION_FIXED,
                     @format_o.split_rules)
      }
      assert_equal(FIVE_CNT, @format_o.format(GETTYSBURG))
    end

      # Tests both nobreak and nobreak_regex, since one is only useful
      # with the other.
    def test_nobreak
      assert_nothing_raised { @format_o = Text::Format.new }
      assert(!@format_o.nobreak)
      assert(@format_o.nobreak_regex.empty?)
      assert_nothing_raised {
        @format_o.nobreak = true
        @format_o.nobreak_regex = { '^this$' => '^continent$' }
        @format_o.columns = 77
      }
      assert(@format_o.nobreak)
      assert_equal({ '^this$' => '^continent$' }, @format_o.nobreak_regex)
      assert_match(/^this continent/,
                   @format_o.format(GETTYSBURG).split("\n")[1])
    end

    def test_right_align?
      assert_nothing_raised { @format_o = Text::Format.new }
      assert(!@format_o.right_align?)
      assert_nothing_raised {
        @format_o.format_style = Text::Format::RIGHT_ALIGN
      }
      assert(@format_o.right_align?)
      assert_nothing_raised {
        @format_o.format_style = Text::Format::RIGHT_FILL
      }
      assert(!@format_o.right_align?)
      assert_nothing_raised { @format_o.format_style = Text::Format::JUSTIFY }
      assert(!@format_o.right_align?)
        # The format testing is done in test_format_style
    end

    def test_right_fill?
      assert_nothing_raised { @format_o = Text::Format.new }
      assert(!@format_o.right_fill?)
      assert_nothing_raised {
        @format_o.format_style = Text::Format::RIGHT_ALIGN
      }
      assert(!@format_o.right_fill?)
      assert_nothing_raised {
        @format_o.format_style = Text::Format::RIGHT_FILL
      }
      assert(@format_o.right_fill?)
      assert_nothing_raised {
        @format_o.format_style = Text::Format::JUSTIFY
      }
      assert(!@format_o.right_fill?)
        # The format testing is done in test_format_style
    end

    def test_right_margin
      assert_nothing_raised { @format_o = Text::Format.new }
      assert_equal(0, @format_o.right_margin)
      assert_nothing_raised { @format_o.right_margin = -3 }
      assert_equal(3, @format_o.right_margin)
      assert_nothing_raised { @format_o.right_margin = "9" }
      assert_equal(9, @format_o.right_margin)
      assert_nothing_raised { @format_o.right_margin = "-2" }
      assert_equal(2, @format_o.right_margin)
      assert_nothing_raised { @format_o.right_margin = 7 }
      assert_equal(7, @format_o.right_margin)
      assert_nothing_raised {
        ft = @format_o.format(GETTYSBURG).split("\n")
        assert_match(/^ {4}Four score.*forth on$/, ft[0])
        assert_match(/^November/, ft[-1])
      }
    end

    def test_tabstop
      assert_nothing_raised { @format_o = Text::Format.new }
      assert_equal(8, @format_o.tabstop)
      assert_nothing_raised { @format_o.tabstop = 7 }
      assert_equal(7, @format_o.tabstop)
      assert_nothing_raised { @format_o.tabstop = -3 }
      assert_equal(3, @format_o.tabstop)
      assert_nothing_raised { @format_o.tabstop = "9" }
      assert_equal(9, @format_o.tabstop)
      assert_nothing_raised { @format_o.tabstop = "-2" }
      assert_equal(2, @format_o.tabstop)
    end

    def test_text
      assert_nothing_raised { @format_o = Text::Format.new }
      assert_equal([], @format_o.text)
      assert_nothing_raised { @format_o.text = "Test Text" }
      assert_equal("Test Text", @format_o.text)
      assert_nothing_raised { @format_o.text = ["Line 1", "Line 2"] }
      assert_equal(["Line 1", "Line 2"], @format_o.text)
    end

    def test_s_new
          # new(NilClass) { block }
      assert_nothing_raised do
        @format_o = Text::Format.new {
          self.text = "Test 1, 2, 3"
        }
      end
      assert_equal("Test 1, 2, 3", @format_o.text)

        # new(Hash Symbols)
      assert_nothing_raised { @format_o = Text::Format.new(:columns => 72) }
      assert_equal(72, @format_o.columns)

        # new(Hash String)
      assert_nothing_raised { @format_o = Text::Format.new('columns' => 72) }
      assert_equal(72, @format_o.columns)

        # new(Hash) { block }
      assert_nothing_raised do
        @format_o = Text::Format.new('columns' => 80) {
          self.text = "Test 4, 5, 6"
        }
      end
      assert_equal("Test 4, 5, 6", @format_o.text)
      assert_equal(80, @format_o.columns)

        # new(Text::Format)
      assert_nothing_raised do
        fo = Text::Format.new(@format_o)
        assert(fo == @format_o)
      end

        # new(Text::Format) { block }
      assert_nothing_raised do
        fo = Text::Format.new(@format_o) { self.columns = 79 }
        assert(fo != @format_o)
      end

          # new(String)
      assert_nothing_raised { @format_o = Text::Format.new("Test A, B, C") }
      assert_equal("Test A, B, C", @format_o.text)

          # new(String) { block }
      assert_nothing_raised do
        @format_o = Text::Format.new("Test X, Y, Z") { self.columns = -5 }
      end
      assert_equal("Test X, Y, Z", @format_o.text)
      assert_equal(5, @format_o.columns)
    end

    def test_center
      assert_nothing_raised { @format_o = Text::Format.new }
      assert_nothing_raised do
        ct = @format_o.center(GETTYSBURG.split("\n")).split("\n")
        assert_match(/^    Four score and seven years ago our fathers brought forth on this/, ct[0])
        assert_match(/^                       not perish from the earth./, ct[-3])
      end
    end

    def test_expand
      assert_nothing_raised { @format_o = Text::Format.new }
      assert_equal("          ", @format_o.expand("\t  "))
      assert_nothing_raised { @format_o.tabstop = 4 }
      assert_equal("      ", @format_o.expand("\t  "))
    end

    def test_unexpand
      assert_nothing_raised { @format_o = Text::Format.new }
      assert_equal("\t  ", @format_o.unexpand("          "))
      assert_nothing_raised { @format_o.tabstop = 4 }
      assert_equal("\t  ", @format_o.unexpand("      "))
    end

    def test_space_only
      assert_equal("", Text::Format.new.format(" "))
      assert_equal("", Text::Format.new.format("\n"))
      assert_equal("", Text::Format.new.format("        "))
      assert_equal("", Text::Format.new.format("    \n"))
      assert_equal("", Text::Format.new.paragraphs("\n"))
      assert_equal("", Text::Format.new.paragraphs(" "))
      assert_equal("", Text::Format.new.paragraphs("        "))
      assert_equal("", Text::Format.new.paragraphs("    \n"))
      assert_equal("", Text::Format.new.paragraphs(["\n"]))
      assert_equal("", Text::Format.new.paragraphs([" "]))
      assert_equal("", Text::Format.new.paragraphs(["        "]))
      assert_equal("", Text::Format.new.paragraphs(["    \n"]))
    end

    def test_splendiferous
      h = nil
      test = "This is a splendiferous test"
      assert_nothing_raised { @format_o = Text::Format.new(:columns => 6, :left_margin => 0, :indent => 0, :first_indent => 0) }
      assert_match(/^splendiferous$/, @format_o.format(test))
      assert_nothing_raised { @format_o.hard_margins = true }
      assert_match(/^lendif$/, @format_o.format(test))
      assert_nothing_raised { h = Object.new }
      assert_nothing_raised do
        @format_o.split_rules = Text::Format::SPLIT_HYPHENATION
        class << h #:nodoc:
          def hyphenate_to(word, size)
            return ["", word] if size < 2
            [word[0 ... size], word[size .. -1]]
          end
        end
        @format_o.hyphenator = h
      end
      assert_match(/^iferou$/, @format_o.format(test))
      assert_nothing_raised { h = Object.new }
      assert_nothing_raised do
        class << h #:nodoc:
          def hyphenate_to(word, size, formatter)
            return ["", word] if word.size < formatter.columns
            [word[0 ... size], word[size .. -1]]
          end
        end
        @format_o.hyphenator = h
      end
      assert_match(/^ferous$/, @format_o.format(test))
    end
  end
end
