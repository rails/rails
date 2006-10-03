require File.dirname(__FILE__) + '/abstract_unit'
require 'open-uri'

$KCODE = 'UTF8'
UNIDATA_URL = "http://www.unicode.org/Public/#{ActiveSupport::Multibyte::UNICODE_VERSION}/ucd"
UNIDATA_FILE = '/NormalizationTest.txt'
CACHE_DIR = File.dirname(__FILE__) + '/cache'

class Downloader
  def self.download(from, to)
    unless File.exist?(to)
      $stderr.puts "Downloading #{from} to #{to}"
      unless File.exists?(File.dirname(to))
        system "mkdir -p #{File.dirname(to)}"
      end
      open(from) do |source|
        File.open(to, 'w') do |target|
          source.each_line do |l|
            target.write l
          end
        end
       end
     end
  end
end

class String
  # Unicode Inspect returns the codepoints of the string in hex
  def ui
    "#{self} " + ("[%s]" % unpack("U*").map{|cp| cp.to_s(16) }.join(' '))
  end unless ''.respond_to?(:ui)
end

Dir.mkdir(CACHE_DIR) unless File.exists?(CACHE_DIR)
Downloader.download(UNIDATA_URL + UNIDATA_FILE, CACHE_DIR + UNIDATA_FILE)

module ConformanceTest
  def test_normalizations_C
    each_line_of_norm_tests do |*cols|
      col1, col2, col3, col4, col5, comment = *cols
      
      # CONFORMANCE:
      # 1. The following invariants must be true for all conformant implementations
      #
      #    NFC
      #      c2 ==  NFC(c1) ==  NFC(c2) ==  NFC(c3)
      assert_equal col2.ui, @handler.normalize(col1, :c).ui, "Form C - Col 2 has to be NFC(1) - #{comment}"
      assert_equal col2.ui, @handler.normalize(col2, :c).ui, "Form C - Col 2 has to be NFC(2) - #{comment}"
      assert_equal col2.ui, @handler.normalize(col3, :c).ui, "Form C - Col 2 has to be NFC(3) - #{comment}"
      #
      #      c4 ==  NFC(c4) ==  NFC(c5)
      assert_equal col4.ui, @handler.normalize(col4, :c).ui, "Form C - Col 4 has to be C(4) - #{comment}"
      assert_equal col4.ui, @handler.normalize(col5, :c).ui, "Form C - Col 4 has to be C(5) - #{comment}"
    end
  end
  
  def test_normalizations_D
    each_line_of_norm_tests do |*cols|
      col1, col2, col3, col4, col5, comment = *cols
      #
      #    NFD
      #      c3 ==  NFD(c1) ==  NFD(c2) ==  NFD(c3)
      assert_equal col3.ui, @handler.normalize(col1, :d).ui, "Form D - Col 3 has to be NFD(1) - #{comment}"
      assert_equal col3.ui, @handler.normalize(col2, :d).ui, "Form D - Col 3 has to be NFD(2) - #{comment}"
      assert_equal col3.ui, @handler.normalize(col3, :d).ui, "Form D - Col 3 has to be NFD(3) - #{comment}"
      #      c5 ==  NFD(c4) ==  NFD(c5)
      assert_equal col5.ui, @handler.normalize(col4, :d).ui, "Form D - Col 5 has to be NFD(4) - #{comment}"
      assert_equal col5.ui, @handler.normalize(col5, :d).ui, "Form D - Col 5 has to be NFD(5) - #{comment}"
    end
  end
  
  def test_normalizations_KC
    each_line_of_norm_tests do | *cols |
      col1, col2, col3, col4, col5, comment = *cols  
      #
      #    NFKC
      #      c4 == NFKC(c1) == NFKC(c2) == NFKC(c3) == NFKC(c4) == NFKC(c5)
      assert_equal col4.ui, @handler.normalize(col1, :kc).ui, "Form D - Col 4 has to be NFKC(1) - #{comment}"
      assert_equal col4.ui, @handler.normalize(col2, :kc).ui, "Form D - Col 4 has to be NFKC(2) - #{comment}"
      assert_equal col4.ui, @handler.normalize(col3, :kc).ui, "Form D - Col 4 has to be NFKC(3) - #{comment}"
      assert_equal col4.ui, @handler.normalize(col4, :kc).ui, "Form D - Col 4 has to be NFKC(4) - #{comment}"
      assert_equal col4.ui, @handler.normalize(col5, :kc).ui, "Form D - Col 4 has to be NFKC(5) - #{comment}"
    end
  end
  
  def test_normalizations_KD
    each_line_of_norm_tests do | *cols |
      col1, col2, col3, col4, col5, comment = *cols  
      #
      #    NFKD
      #      c5 == NFKD(c1) == NFKD(c2) == NFKD(c3) == NFKD(c4) == NFKD(c5)
      assert_equal col5.ui, @handler.normalize(col1, :kd).ui, "Form KD - Col 5 has to be NFKD(1) - #{comment}"
      assert_equal col5.ui, @handler.normalize(col2, :kd).ui, "Form KD - Col 5 has to be NFKD(2) - #{comment}"
      assert_equal col5.ui, @handler.normalize(col3, :kd).ui, "Form KD - Col 5 has to be NFKD(3) - #{comment}"
      assert_equal col5.ui, @handler.normalize(col4, :kd).ui, "Form KD - Col 5 has to be NFKD(4) - #{comment}"
      assert_equal col5.ui, @handler.normalize(col5, :kd).ui, "Form KD - Col 5 has to be NFKD(5) - #{comment}"
    end
  end
  
  protected
    def each_line_of_norm_tests(&block)
      lines = 0
      max_test_lines = 0 # Don't limit below 38, because that's the header of the testfile
      File.open(File.dirname(__FILE__) + '/cache' + UNIDATA_FILE, 'r') do | f |
        until f.eof? || (max_test_lines > 38 and lines > max_test_lines)
          lines += 1
          line = f.gets.chomp!
          next if (line.empty? || line =~ /^\#/)      
          
          cols, comment = line.split("#")
          cols = cols.split(";").map{|e| e.strip}.reject{|e| e.empty? }
          next unless cols.length == 5
          
          # codepoints are in hex in the test suite, pack wants them as integers
          cols.map!{|c| c.split.map{|codepoint| codepoint.to_i(16)}.pack("U*") }
          cols << comment
          
          yield(*cols)
        end
      end
    end
end

begin
  require_library_or_gem('utf8proc_native')
  require 'active_record/multibyte/handlers/utf8_handler_proc'
  class ConformanceTestProc < Test::Unit::TestCase
    include ConformanceTest
    def setup
      @handler = ::ActiveSupport::Multibyte::Handlers::UTF8HandlerProc
    end
  end
rescue LoadError
end

class ConformanceTestPure < Test::Unit::TestCase
  include ConformanceTest
  def setup
    @handler = ::ActiveSupport::Multibyte::Handlers::UTF8Handler
  end
end