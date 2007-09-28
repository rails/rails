require File.dirname(__FILE__) + '/abstract_unit'

$KCODE = 'UTF8'

class String
  # Unicode Inspect returns the codepoints of the string in hex
  def ui
    "#{self} " + ("[%s]" % unpack("U*").map{|cp| cp.to_s(16) }.join(' '))
  end unless ''.respond_to?(:ui)
end

module UTF8HandlingTest
  
  def common_setup
    # This is an ASCII string with some russian strings and a ligature. It's nicely calibrated, because
    # slicing it at some specific bytes will kill your characters if you use standard Ruby routines.
    # It has both capital and standard letters, so that we can test case conversions easily.
    # It has 26 characters and 28 when the ligature gets split during normalization.
    @string =     "Abcd Блå ﬃ бла бла бла бла"
    @string_kd =  "Abcd Блå ffi бла бла бла бла"
    @string_kc =  "Abcd Блå ffi бла бла бла бла"
    @string_c =   "Abcd Блå ﬃ бла бла бла бла"
    @string_d =   "Abcd Блå ﬃ бла бла бла бла"
    @bytestring = "\270\236\010\210\245" # Not UTF-8
    
    # Characters from the character classes as described in UAX #29
    @character_from_class = {
      :l => 0x1100, :v => 0x1160, :t => 0x11A8, :lv => 0xAC00, :lvt => 0xAC01, :cr => 0x000D, :lf => 0x000A,
      :extend => 0x094D, :n => 0x64
    }
  end
  
  def test_utf8_recognition
    assert ActiveSupport::Multibyte::Handlers::UTF8Handler.consumes?(@string),
      "Should recognize as a valid UTF-8 string"
    assert !ActiveSupport::Multibyte::Handlers::UTF8Handler.consumes?(@bytestring), "This is bytestring, not UTF-8"
  end
  
  def test_simple_normalization
    # Normalization of DEVANAGARI LETTER QA breaks when composition exclusion isn't used correctly
    assert_equal [0x915, 0x93c].pack('U*').ui, [0x915, 0x93c].pack('U*').chars.normalize(:c).to_s.ui
    
    null_byte_str = "Test\0test"
    
    assert_equal '', @handler.normalize(''), "Empty string should not break things"
    assert_equal null_byte_str.ui, @handler.normalize(null_byte_str, :kc).ui, "Null byte should remain"
    assert_equal null_byte_str.ui, @handler.normalize(null_byte_str, :c).ui, "Null byte should remain" 
    assert_equal null_byte_str.ui, @handler.normalize(null_byte_str, :d).ui, "Null byte should remain"
    assert_equal null_byte_str.ui, @handler.normalize(null_byte_str, :kd).ui, "Null byte should remain"
    assert_equal null_byte_str.ui, @handler.decompose(null_byte_str).ui, "Null byte should remain"
    assert_equal null_byte_str.ui, @handler.compose(null_byte_str).ui, "Null byte should remain" 
    
    comp_str = [
      44,  # LATIN CAPITAL LETTER D
      307, # COMBINING DOT ABOVE
      328, # COMBINING OGONEK
      323 # COMBINING DOT BELOW
    ].pack("U*")
    norm_str_KC = [44,105,106,328,323].pack("U*")
    norm_str_C = [44,307,328,323].pack("U*")
    norm_str_D = [44,307,110,780,78,769].pack("U*")
    norm_str_KD = [44,105,106,110,780,78,769].pack("U*")
    
    assert_equal norm_str_KC.ui, @handler.normalize(comp_str, :kc).ui, "Should normalize KC"
    assert_equal norm_str_C.ui, @handler.normalize(comp_str, :c).ui, "Should normalize C"
    assert_equal norm_str_D.ui, @handler.normalize(comp_str, :d).ui, "Should normalize D"
    assert_equal norm_str_KD.ui, @handler.normalize(comp_str, :kd).ui, "Should normalize KD"
    
    assert_raise(ActiveSupport::Multibyte::Handlers::EncodingError) { @handler.normalize(@bytestring) }
  end
  
  # Test for the Public Review Issue #29, bad explaination of composition might lead to a
  # bad implementation: http://www.unicode.org/review/pr-29.html
  def test_normalization_C_pri_29
    [
      [0x0B47, 0x0300, 0x0B3E],
      [0x1100, 0x0300, 0x1161]
    ].map { |c| c.pack('U*') }.each do |c|
      assert_equal c.ui, @handler.normalize(c, :c).ui, "Composition is implemented incorrectly"
    end
  end
  
  def test_casefolding
    simple_str = "abCdef"
    simple_str_upcase = "ABCDEF"
    simple_str_downcase = "abcdef"
    
    assert_equal '', @handler.downcase(@handler.upcase('')), "Empty string should not break things"
    assert_equal simple_str_upcase, @handler.upcase(simple_str), "should upcase properly"
    assert_equal simple_str_downcase, @handler.downcase(simple_str), "should downcase properly"
    assert_equal simple_str_downcase, @handler.downcase(@handler.upcase(simple_str_downcase)), "upcase and downcase should be mirrors"
    
    rus_str = "аБвгд\0f"
    rus_str_upcase = "АБВГД\0F"
    rus_str_downcase = "абвгд\0f"
    assert_equal rus_str_upcase, @handler.upcase(rus_str), "should upcase properly honoring null-byte"
    assert_equal rus_str_downcase, @handler.downcase(rus_str), "should downcase properly honoring null-byte"
    
    jap_str = "の埋め込み化対応はほぼ完成"
    assert_equal jap_str, @handler.upcase(jap_str), "Japanse has no upcase, should remain unchanged"
    assert_equal jap_str, @handler.downcase(jap_str), "Japanse has no downcase, should remain unchanged"
    
    assert_raise(ActiveSupport::Multibyte::Handlers::EncodingError) { @handler.upcase(@bytestring) }
  end
  
  def test_capitalize
    { 'аБвг аБвг' => 'Абвг абвг',
      'аБвг АБВГ' => 'Абвг абвг',
      'АБВГ АБВГ' => 'Абвг абвг',
      '' => '' }.each do |f,t|
        assert_equal t, @handler.capitalize(f), "Capitalize should work as expected"
    end
    assert_raise(ActiveSupport::Multibyte::Handlers::EncodingError) { @handler.capitalize(@bytestring) }
  end
  
  def test_translate_offset
    str = "Блaå" # [2, 2, 1, 2] bytes
    assert_equal 0, @handler.translate_offset('', 0), "Offset for an empty string makes no sense, return 0"
    assert_equal 0, @handler.translate_offset(str, 0), "First character, first byte"
    assert_equal 0, @handler.translate_offset(str, 1), "First character, second byte"
    assert_equal 1, @handler.translate_offset(str, 2), "Second character, third byte"
    assert_equal 1, @handler.translate_offset(str, 3), "Second character, fourth byte"
    assert_equal 2, @handler.translate_offset(str, 4), "Third character, fifth byte"
    assert_equal 3, @handler.translate_offset(str, 5), "Fourth character, sixth byte"
    assert_equal 3, @handler.translate_offset(str, 6), "Fourth character, seventh byte"
    assert_raise(ActiveSupport::Multibyte::Handlers::EncodingError) { @handler.translate_offset(@bytestring, 3) }
  end
  
  def test_insert
    assert_equal '', @handler.insert('', 0, ''), "Empty string should not break things"
    assert_equal "Abcd Блå ﬃБУМ бла бла бла бла", @handler.insert(@string, 10, "БУМ"), 
      "Text should be inserted at right codepoints"
    assert_equal "Abcd Блå ﬃБУМ бла бла бла бла", @string, "Insert should be destructive"
    assert_raise(ActiveSupport::Multibyte::Handlers::EncodingError) do
      @handler.insert(@bytestring, 2, "\210")
    end
  end
  
  def test_reverse
    str = "wБлåa \n"
    rev = "\n aåлБw"
    assert_equal '', @handler.reverse(''), "Empty string shouldn't change"
    assert_equal rev.ui, @handler.reverse(str).ui, "Should reverse properly"
    assert_raise(ActiveSupport::Multibyte::Handlers::EncodingError) { @handler.reverse(@bytestring) }
  end
  
  def test_size
    assert_equal 0, @handler.size(''), "Empty string has size 0"
    assert_equal 26, @handler.size(@string), "String length should be 26"
    assert_equal 26, @handler.length(@string), "String length method should be properly aliased"
    assert_raise(ActiveSupport::Multibyte::Handlers::EncodingError) { @handler.size(@bytestring) }
  end
  
  def test_slice
    assert_equal 0x41, @handler.slice(@string, 0), "Singular characters should return codepoints"
    assert_equal 0xE5, @handler.slice(@string, 7), "Singular characters should return codepoints"
    assert_equal nil, @handler.slice('', -1..1), "Broken range should return nil"
    assert_equal '', @handler.slice('', 0..10), "Empty string should not break things"
    assert_equal "d Блå ﬃ", @handler.slice(@string, 3..9), "Unicode characters have to be returned"
    assert_equal "d Блå ﬃ", @handler.slice(@string, 3, 7), "Unicode characters have to be returned"
    assert_equal "A", @handler.slice(@string, 0, 1), "Slicing from an offset should return characters"
    assert_equal " Блå ﬃ ", @handler.slice(@string, 4..10), "Unicode characters have to be returned"
    assert_equal "", @handler.slice(@string, 7..6), "Range is empty, should return an empty string"
    assert_raise(ActiveSupport::Multibyte::Handlers::EncodingError) { @handler.slice(@bytestring, 2..3) }
    assert_raise(TypeError, "With 2 args, should raise TypeError for non-Numeric or Regexp first argument") { @handler.slice(@string, 2..3, 1) }
    assert_raise(TypeError, "With 2 args, should raise TypeError for non-Numeric or Regexp second argument") { @handler.slice(@string, 1, 2..3) }
    assert_raise(ArgumentError, "Should raise ArgumentError when there are more than 2 args") { @handler.slice(@string, 1, 1, 1) }
  end
  
  def test_grapheme_cluster_length
    assert_equal 0, @handler.g_length(''), "String should count 0 grapheme clusters"
    assert_equal 2, @handler.g_length([0x0924, 0x094D, 0x0930].pack('U*')), "String should count 2 grapheme clusters"
    assert_equal 1, @handler.g_length(string_from_classes(%w(cr lf))), "Don't cut between CR and LF"
    assert_equal 1, @handler.g_length(string_from_classes(%w(l l))), "Don't cut between L"
    assert_equal 1, @handler.g_length(string_from_classes(%w(l v))), "Don't cut between L and V"
    assert_equal 1, @handler.g_length(string_from_classes(%w(l lv))), "Don't cut between L and LV"
    assert_equal 1, @handler.g_length(string_from_classes(%w(l lvt))), "Don't cut between L and LVT"
    assert_equal 1, @handler.g_length(string_from_classes(%w(lv v))), "Don't cut between LV and V"
    assert_equal 1, @handler.g_length(string_from_classes(%w(lv t))), "Don't cut between LV and T"
    assert_equal 1, @handler.g_length(string_from_classes(%w(v v))), "Don't cut between V and V"
    assert_equal 1, @handler.g_length(string_from_classes(%w(v t))), "Don't cut between V and T"
    assert_equal 1, @handler.g_length(string_from_classes(%w(lvt t))), "Don't cut between LVT and T"
    assert_equal 1, @handler.g_length(string_from_classes(%w(t t))), "Don't cut between T and T"
    assert_equal 1, @handler.g_length(string_from_classes(%w(n extend))), "Don't cut before Extend"
    assert_equal 2, @handler.g_length(string_from_classes(%w(n n))), "Cut between normal characters"
    assert_equal 3, @handler.g_length(string_from_classes(%w(n cr lf n))), "Don't cut between CR and LF"
    assert_equal 2, @handler.g_length(string_from_classes(%w(n l v t))), "Don't cut between L, V and T"
    assert_raise(ActiveSupport::Multibyte::Handlers::EncodingError) { @handler.g_length(@bytestring) }
  end
  
  def test_index
     s = "Καλημέρα κόσμε!"
     assert_equal 0, @handler.index('', ''), "The empty string is always found at the beginning of the string"
     assert_equal 0, @handler.index('haystack', ''), "The empty string is always found at the beginning of the string"
     assert_equal 0, @handler.index(s, 'Κ'), "Greek K is at 0"
     assert_equal 1, @handler.index(s, 'α'), "Greek Alpha is at 1"
     
     assert_equal nil, @handler.index(@bytestring, 'a')
     assert_raise(ActiveSupport::Multibyte::Handlers::EncodingError) { @handler.index(@bytestring, "\010") }
  end
  
  def test_indexed_insert
    s = "Καλη!"
    @handler[s, 2] = "a"
    assert_equal "Καaη!", s
    @handler[s, 2] = "ηη"
    assert_equal "Καηηη!", s
    assert_raises(IndexError) { @handler[s, 10] = 'a' }
    assert_equal "Καηηη!", s
    @handler[s, 2] = 32
    assert_equal "Κα ηη!", s
    @handler[s, 3, 2] = "λλλ"
    assert_equal "Κα λλλ!", s
    @handler[s, 1, 0] = "λ"
    assert_equal "Κλα λλλ!", s
    assert_raises(IndexError) { @handler[s, 10, 4] = 'a' }
    assert_equal "Κλα λλλ!", s
    @handler[s, 4..6] = "ηη"
    assert_equal "Κλα ηη!", s
    assert_raises(RangeError) { @handler[s, 10..12] = 'a' }
    assert_equal "Κλα ηη!", s
    @handler[s, /ηη/] = "λλλ"
    assert_equal "Κλα λλλ!", s
    assert_raises(IndexError) { @handler[s, /ii/] = 'a' }
    assert_equal "Κλα λλλ!", s
    @handler[s, /(λλ)(.)/, 2] = "α"
    assert_equal "Κλα λλα!", s
    assert_raises(IndexError) { @handler[s, /()/, 10] = 'a' }
    assert_equal "Κλα λλα!", s
    @handler[s, "α"] = "η"
    assert_equal "Κλη λλα!", s
    @handler[s, "λλ"] = "ααα"
    assert_equal "Κλη αααα!", s
  end
  
  def test_rjust
    s = "Καη"
    assert_raises(ArgumentError) { @handler.rjust(s, 10, '') }
    assert_raises(ArgumentError) { @handler.rjust(s) }
    assert_equal "Καη", @handler.rjust(s, -3)
    assert_equal "Καη", @handler.rjust(s, 0)
    assert_equal "Καη", @handler.rjust(s, 3)
    assert_equal "  Καη", @handler.rjust(s, 5)
    assert_equal "    Καη", @handler.rjust(s, 7)
    assert_equal "----Καη", @handler.rjust(s, 7, '-')
    assert_equal "ααααΚαη", @handler.rjust(s, 7, 'α')
    assert_equal "abaΚαη", @handler.rjust(s, 6, 'ab')
    assert_equal "αηαΚαη", @handler.rjust(s, 6, 'αη')
  end
  
  def test_ljust
    s = "Καη"
    assert_raises(ArgumentError) { @handler.ljust(s, 10, '') }
    assert_raises(ArgumentError) { @handler.ljust(s) }
    assert_equal "Καη", @handler.ljust(s, -3)
    assert_equal "Καη", @handler.ljust(s, 0)
    assert_equal "Καη", @handler.ljust(s, 3)
    assert_equal "Καη  ", @handler.ljust(s, 5)
    assert_equal "Καη    ", @handler.ljust(s, 7)
    assert_equal "Καη----", @handler.ljust(s, 7, '-')
    assert_equal "Καηαααα", @handler.ljust(s, 7, 'α')
    assert_equal "Καηaba", @handler.ljust(s, 6, 'ab')
    assert_equal "Καηαηα", @handler.ljust(s, 6, 'αη')
  end
  
  def test_center
    s = "Καη"
    assert_raises(ArgumentError) { @handler.center(s, 10, '') }
    assert_raises(ArgumentError) { @handler.center(s) }
    assert_equal "Καη", @handler.center(s, -3)
    assert_equal "Καη", @handler.center(s, 0)
    assert_equal "Καη", @handler.center(s, 3)
    assert_equal "Καη ", @handler.center(s, 4)
    assert_equal " Καη ", @handler.center(s, 5)
    assert_equal " Καη  ", @handler.center(s, 6)
    assert_equal "--Καη--", @handler.center(s, 7, '-')
    assert_equal "--Καη---", @handler.center(s, 8, '-')
    assert_equal "ααΚαηαα", @handler.center(s, 7, 'α')
    assert_equal "ααΚαηααα", @handler.center(s, 8, 'α')
    assert_equal "aΚαηab", @handler.center(s, 6, 'ab')
    assert_equal "abΚαηab", @handler.center(s, 7, 'ab')
    assert_equal "ababΚαηabab", @handler.center(s, 11, 'ab')
    assert_equal "αΚαηαη", @handler.center(s, 6, 'αη')
    assert_equal "αηΚαηαη", @handler.center(s, 7, 'αη')
  end
  
  def test_strip
    # A unicode aware version of strip should strip all 26 types of whitespace. This includes the NO BREAK SPACE
    # aka BOM (byte order mark). The byte order mark has no place in UTF-8 because it's used to detect LE and BE.
    b = "\n" + [
      32, # SPACE
      8195, # EM SPACE
      8199, # FIGURE SPACE,
      8201, # THIN SPACE
      8202, # HAIR SPACE
      65279, # NO BREAK SPACE (ZW)
    ].pack('U*')
    m = "word блин\n\n\n  word"
    e = [
    65279, # NO BREAK SPACE (ZW)
    8201, # THIN SPACE
    8199, # FIGURE SPACE,      
    32, # SPACE
    ].pack('U*')
    string = b+m+e
    
    assert_equal '', @handler.strip(''), "Empty string should stay empty"
    assert_equal m+e, @handler.lstrip(string), "Whitespace should be gone on the left"
    assert_equal b+m, @handler.rstrip(string), "Whitespace should be gone on the right"
    assert_equal m, @handler.strip(string), "Whitespace should be stripped on both sides"
    
    bs = "\n   #{@bytestring} \n\n"
    assert_equal @bytestring, @handler.strip(bs), "Invalid unicode strings should still strip"
  end
  
  def test_tidy_bytes
    result = [0xb8, 0x17e, 0x8, 0x2c6, 0xa5].pack('U*')
    assert_equal result, @handler.tidy_bytes(@bytestring)
    assert_equal "a#{result}a", @handler.tidy_bytes('a' + @bytestring + 'a'),
      'tidy_bytes should leave surrounding characters intact'
    assert_equal "é#{result}é", @handler.tidy_bytes('é' + @bytestring + 'é'),
      'tidy_bytes should leave surrounding characters intact'
    assert_nothing_raised { @handler.tidy_bytes(@bytestring).unpack('U*') }
    
    assert_equal "\xC3\xA7", @handler.tidy_bytes("\xE7") # iso_8859_1: small c cedilla
    assert_equal "\xC2\xA9", @handler.tidy_bytes("\xA9") # iso_8859_1: copyright symbol
    assert_equal "\xE2\x80\x9C", @handler.tidy_bytes("\x93") # win_1252: left smart quote
    assert_equal "\xE2\x82\xAC", @handler.tidy_bytes("\x80") # win_1252: euro
    assert_equal "\x00", @handler.tidy_bytes("\x00") # null char
    assert_equal [0xfffd].pack('U'), @handler.tidy_bytes("\xef\xbf\xbd") # invalid char
  end
  
  protected
  
  def string_from_classes(classes)
    classes.collect do |k|
      @character_from_class[k.intern]
    end.pack('U*')
  end
end


begin
  require_library_or_gem('utf8proc_native')
  require 'active_record/multibyte/handlers/utf8_handler_proc'
  class UTF8HandlingTestProc < Test::Unit::TestCase
    include UTF8HandlingTest
    def setup
      common_setup
      @handler = ::ActiveSupport::Multibyte::Handlers::UTF8HandlerProc
    end
  end
rescue LoadError
end

class UTF8HandlingTestPure < Test::Unit::TestCase
  include UTF8HandlingTest
  def setup
    common_setup
    @handler = ::ActiveSupport::Multibyte::Handlers::UTF8Handler
  end
end
