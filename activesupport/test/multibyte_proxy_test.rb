# frozen_string_literal: true

require_relative "abstract_unit"

class MultibyteProxyText < ActiveSupport::TestCase
  class AsciiOnlyEncoder
    attr_reader :wrapped_string
    alias to_s wrapped_string

    def initialize(string)
      @wrapped_string = string.gsub(/[^\u0000-\u007F]/, "?")
    end
  end

  def with_custom_encoder(encoder)
    original_proxy_class = ActiveSupport::Multibyte.proxy_class

    begin
      ActiveSupport::Multibyte.proxy_class = encoder

      yield
    ensure
      ActiveSupport::Multibyte.proxy_class = original_proxy_class
    end
  end

  test "custom multibyte encoder" do
    assert_deprecated ActiveSupport.deprecator do
      with_custom_encoder(AsciiOnlyEncoder) do
        assert_equal "s?me string 123", "søme string 123".mb_chars.to_s
      end

      assert_equal "søme string 123", "søme string 123".mb_chars.to_s
    end
  end
end
