# frozen_string_literal: true

require_relative "abstract_unit"
require_relative "multibyte_test_helpers"

class MultibyteGraphemeBreakConformanceTest < ActiveSupport::TestCase
  include MultibyteTestHelpers

  UNIDATA_FILE = "/auxiliary/GraphemeBreakTest.txt"
  RUN_P = begin
            Downloader.download(UNIDATA_URL + UNIDATA_FILE, CACHE_DIR + UNIDATA_FILE)
          rescue
          end

  def setup
    skip "Unable to download test data" unless RUN_P
  end

  def test_breaks
    ActiveSupport::Deprecation.silence do
      each_line_of_break_tests do |*cols|
        *clusters, comment = *cols
        packed = ActiveSupport::Multibyte::Unicode.pack_graphemes(clusters)
        assert_equal clusters, ActiveSupport::Multibyte::Unicode.unpack_graphemes(packed), comment
      end
    end
  end

  private
    def each_line_of_break_tests(&block)
      lines = 0
      max_test_lines = 0 # Don't limit below 21, because that's the header of the testfile
      File.open(File.join(CACHE_DIR, UNIDATA_FILE), "r") do | f |
        until f.eof? || (max_test_lines > 21 && lines > max_test_lines)
          lines += 1
          line = f.gets.chomp!
          next if line.empty? || line.start_with?("#")

          cols, comment = line.split("#")
          # Cluster breaks are represented by ÷
          clusters = cols.split("÷").map { |e| e.strip }.reject { |e| e.empty? }
          clusters = clusters.map do |cluster|
            # Codepoints within each cluster are separated by ×
            codepoints = cluster.split("×").map { |e| e.strip }.reject { |e| e.empty? }
            # codepoints are in hex in the test suite, pack wants them as integers
            codepoints.map { |codepoint| codepoint.to_i(16) }
          end

          # The tests contain a solitary U+D800 <Non Private Use High
          # Surrogate, First> character, which Ruby does not allow to stand
          # alone in a UTF-8 string. So we'll just skip it.
          next if clusters.flatten.include?(0xd800)

          clusters << comment.strip

          yield(*clusters)
        end
      end
    end
end
