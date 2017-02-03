module MultibyteTestHelpers
  class Downloader
    def self.download(from, to)
      unless File.exist?(to)
        unless File.exist?(File.dirname(to))
          system "mkdir -p #{File.dirname(to)}"
        end
        open(from) do |source|
          File.open(to, "w") do |target|
            source.each_line do |l|
              target.write l
            end
          end
        end
      end
      true
    end
  end

  UNIDATA_URL = "http://www.unicode.org/Public/#{ActiveSupport::Multibyte::Unicode::UNICODE_VERSION}/ucd"
  CACHE_DIR = "#{Dir.tmpdir}/cache/unicode_conformance/#{ActiveSupport::Multibyte::Unicode::UNICODE_VERSION}"
  FileUtils.mkdir_p(CACHE_DIR)

  UNICODE_STRING = "こにちわ".freeze
  ASCII_STRING = "ohayo".freeze
  BYTE_STRING = "\270\236\010\210\245".force_encoding("ASCII-8BIT").freeze

  def chars(str)
    ActiveSupport::Multibyte::Chars.new(str)
  end

  def inspect_codepoints(str)
    str.to_s.unpack("U*").map { |cp| cp.to_s(16) }.join(" ")
  end

  def assert_equal_codepoints(expected, actual, message = nil)
    assert_equal(inspect_codepoints(expected), inspect_codepoints(actual), message)
  end
end
