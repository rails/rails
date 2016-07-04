require 'abstract_unit'
require 'multibyte_test_helpers'

require 'fileutils'
require 'open-uri'
require 'tmpdir'

class MultibyteConformanceTest < ActiveSupport::TestCase
  include MultibyteTestHelpers

  UNIDATA_URL = "http://www.unicode.org/Public/#{ActiveSupport::Multibyte::Unicode::UNICODE_VERSION}/ucd"
  UNIDATA_FILE = '/NormalizationTest.txt'
  CACHE_DIR = "#{Dir.tmpdir}/cache/unicode_conformance"
  FileUtils.mkdir_p(CACHE_DIR)
  RUN_P = begin
            Downloader.download(UNIDATA_URL + UNIDATA_FILE, CACHE_DIR + UNIDATA_FILE)
          rescue
          end

  def setup
    @proxy = ActiveSupport::Multibyte::Chars
    skip "Unable to download test data" unless RUN_P
  end

  def test_normalizations_C
    each_line_of_norm_tests do |*cols|
      col1, col2, col3, col4, col5, comment = *cols

      # CONFORMANCE:
      # 1. The following invariants must be true for all conformant implementations
      #
      #    NFC
      #      c2 ==  NFC(c1) ==  NFC(c2) ==  NFC(c3)
      assert_equal_codepoints col2, @proxy.new(col1).normalize(:c), "Form C - Col 2 has to be NFC(1) - #{comment}"
      assert_equal_codepoints col2, @proxy.new(col2).normalize(:c), "Form C - Col 2 has to be NFC(2) - #{comment}"
      assert_equal_codepoints col2, @proxy.new(col3).normalize(:c), "Form C - Col 2 has to be NFC(3) - #{comment}"
      #
      #      c4 ==  NFC(c4) ==  NFC(c5)
      assert_equal_codepoints col4, @proxy.new(col4).normalize(:c), "Form C - Col 4 has to be C(4) - #{comment}"
      assert_equal_codepoints col4, @proxy.new(col5).normalize(:c), "Form C - Col 4 has to be C(5) - #{comment}"
    end
  end

  def test_normalizations_D
    each_line_of_norm_tests do |*cols|
      col1, col2, col3, col4, col5, comment = *cols
      #
      #    NFD
      #      c3 ==  NFD(c1) ==  NFD(c2) ==  NFD(c3)
      assert_equal_codepoints col3, @proxy.new(col1).normalize(:d), "Form D - Col 3 has to be NFD(1) - #{comment}"
      assert_equal_codepoints col3, @proxy.new(col2).normalize(:d), "Form D - Col 3 has to be NFD(2) - #{comment}"
      assert_equal_codepoints col3, @proxy.new(col3).normalize(:d), "Form D - Col 3 has to be NFD(3) - #{comment}"
      #      c5 ==  NFD(c4) ==  NFD(c5)
      assert_equal_codepoints col5, @proxy.new(col4).normalize(:d), "Form D - Col 5 has to be NFD(4) - #{comment}"
      assert_equal_codepoints col5, @proxy.new(col5).normalize(:d), "Form D - Col 5 has to be NFD(5) - #{comment}"
    end
  end

  def test_normalizations_KC
    each_line_of_norm_tests do | *cols |
      col1, col2, col3, col4, col5, comment = *cols
      #
      #    NFKC
      #      c4 == NFKC(c1) == NFKC(c2) == NFKC(c3) == NFKC(c4) == NFKC(c5)
      assert_equal_codepoints col4, @proxy.new(col1).normalize(:kc), "Form D - Col 4 has to be NFKC(1) - #{comment}"
      assert_equal_codepoints col4, @proxy.new(col2).normalize(:kc), "Form D - Col 4 has to be NFKC(2) - #{comment}"
      assert_equal_codepoints col4, @proxy.new(col3).normalize(:kc), "Form D - Col 4 has to be NFKC(3) - #{comment}"
      assert_equal_codepoints col4, @proxy.new(col4).normalize(:kc), "Form D - Col 4 has to be NFKC(4) - #{comment}"
      assert_equal_codepoints col4, @proxy.new(col5).normalize(:kc), "Form D - Col 4 has to be NFKC(5) - #{comment}"
    end
  end

  def test_normalizations_KD
    each_line_of_norm_tests do | *cols |
      col1, col2, col3, col4, col5, comment = *cols
      #
      #    NFKD
      #      c5 == NFKD(c1) == NFKD(c2) == NFKD(c3) == NFKD(c4) == NFKD(c5)
      assert_equal_codepoints col5, @proxy.new(col1).normalize(:kd), "Form KD - Col 5 has to be NFKD(1) - #{comment}"
      assert_equal_codepoints col5, @proxy.new(col2).normalize(:kd), "Form KD - Col 5 has to be NFKD(2) - #{comment}"
      assert_equal_codepoints col5, @proxy.new(col3).normalize(:kd), "Form KD - Col 5 has to be NFKD(3) - #{comment}"
      assert_equal_codepoints col5, @proxy.new(col4).normalize(:kd), "Form KD - Col 5 has to be NFKD(4) - #{comment}"
      assert_equal_codepoints col5, @proxy.new(col5).normalize(:kd), "Form KD - Col 5 has to be NFKD(5) - #{comment}"
    end
  end

  protected
    def each_line_of_norm_tests(&block)
      File.open(File.join(CACHE_DIR, UNIDATA_FILE), 'r') do | f |
        until f.eof?
          line = f.gets.chomp!
          next if (line.empty? || line =~ /^\#/)

          cols, comment = line.split("#")
          cols = cols.split(";").map(&:strip).reject(&:empty?)
          next unless cols.length == 5

          # codepoints are in hex in the test suite, pack wants them as integers
          cols.map!{|c| c.split.map{|codepoint| codepoint.to_i(16)}.pack("U*") }
          cols << comment

          yield(*cols)
        end
      end
    end

    def inspect_codepoints(str)
      str.to_s.unpack("U*").map{|cp| cp.to_s(16) }.join(' ')
    end
end
