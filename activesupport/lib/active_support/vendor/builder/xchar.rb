#!/usr/bin/env ruby

# The XChar library is provided courtesy of Sam Ruby (See
# http://intertwingly.net/stories/2005/09/28/xchar.rb)

# --------------------------------------------------------------------

# If the Builder::XChar module is not currently defined, fail on any
# name clashes in standard library classes.

module Builder
  def self.check_for_name_collision(klass, method_name, defined_constant=nil)
    if klass.instance_methods.include?(method_name)
      fail RuntimeError,
	"Name Collision: Method '#{method_name}' is already defined in #{klass}"
    end
  end
end

if ! defined?(Builder::XChar)
  Builder.check_for_name_collision(String, "to_xs")
  Builder.check_for_name_collision(Fixnum, "xchr")
end

######################################################################
module Builder

  ####################################################################
  # XML Character converter, from Sam Ruby:
  # (see http://intertwingly.net/stories/2005/09/28/xchar.rb). 
  #
  module XChar # :nodoc:

    # See
    # http://intertwingly.net/stories/2004/04/14/i18n.html#CleaningWindows
    # for details.
    CP1252 = {			# :nodoc:
      128 => 8364,		# euro sign
      130 => 8218,		# single low-9 quotation mark
      131 =>  402,		# latin small letter f with hook
      132 => 8222,		# double low-9 quotation mark
      133 => 8230,		# horizontal ellipsis
      134 => 8224,		# dagger
      135 => 8225,		# double dagger
      136 =>  710,		# modifier letter circumflex accent
      137 => 8240,		# per mille sign
      138 =>  352,		# latin capital letter s with caron
      139 => 8249,		# single left-pointing angle quotation mark
      140 =>  338,		# latin capital ligature oe
      142 =>  381,		# latin capital letter z with caron
      145 => 8216,		# left single quotation mark
      146 => 8217,		# right single quotation mark
      147 => 8220,		# left double quotation mark
      148 => 8221,		# right double quotation mark
      149 => 8226,		# bullet
      150 => 8211,		# en dash
      151 => 8212,		# em dash
      152 =>  732,		# small tilde
      153 => 8482,		# trade mark sign
      154 =>  353,		# latin small letter s with caron
      155 => 8250,		# single right-pointing angle quotation mark
      156 =>  339,		# latin small ligature oe
      158 =>  382,		# latin small letter z with caron
      159 =>  376,		# latin capital letter y with diaeresis
    }

    # See http://www.w3.org/TR/REC-xml/#dt-chardata for details.
    PREDEFINED = {
      38 => '&amp;',		# ampersand
      60 => '&lt;',		# left angle bracket
      62 => '&gt;',		# right angle bracket
    }

    # See http://www.w3.org/TR/REC-xml/#charsets for details.
    VALID = [
      [0x9, 0xA, 0xD],
      (0x20..0xD7FF), 
      (0xE000..0xFFFD),
      (0x10000..0x10FFFF)
    ]
  end

end


######################################################################
# Enhance the Fixnum class with a XML escaped character conversion.
#
class Fixnum #:nodoc:
  XChar = Builder::XChar if ! defined?(XChar)

  # XML escaped version of chr
  def xchr
    n = XChar::CP1252[self] || self
    n = 42 unless XChar::VALID.find {|range| range.include? n}
    XChar::PREDEFINED[n] or (n<128 ? n.chr : "&##{n};")
  end
end


######################################################################
# Enhance the String class with a XML escaped character version of
# to_s.
#
class String #:nodoc:
  # XML escaped version of to_s
  def to_xs
    unpack('U*').map {|n| n.xchr}.join # ASCII, UTF-8
  rescue
    unpack('C*').map {|n| n.xchr}.join # ISO-8859-1, WIN-1252
  end
end
