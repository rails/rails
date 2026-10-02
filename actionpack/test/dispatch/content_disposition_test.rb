# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  class ContentDispositionTest < ActiveSupport::TestCase
    test "encoding a Latin filename" do
      disposition = Http::ContentDisposition.new(disposition: :inline, filename: "racecar.jpg")

      assert_equal %(filename="racecar.jpg"), disposition.ascii_filename
      assert_equal "filename*=UTF-8''racecar.jpg", disposition.utf8_filename
      assert_equal "inline; #{disposition.ascii_filename}; #{disposition.utf8_filename}", disposition.to_s
    end

    test "encoding a Latin filename with accented characters" do
      disposition = Http::ContentDisposition.new(disposition: :inline, filename: "råcëçâr.jpg")

      assert_equal %(filename="racecar.jpg"), disposition.ascii_filename
      assert_equal "filename*=UTF-8''r%C3%A5c%C3%AB%C3%A7%C3%A2r.jpg", disposition.utf8_filename
      assert_equal "inline; #{disposition.ascii_filename}; #{disposition.utf8_filename}", disposition.to_s
    end

    test "encoding a non-Latin filename" do
      disposition = Http::ContentDisposition.new(disposition: :inline, filename: "автомобиль.jpg")

      assert_equal %(filename="%3F%3F%3F%3F%3F%3F%3F%3F%3F%3F.jpg"), disposition.ascii_filename
      assert_equal "filename*=UTF-8''%D0%B0%D0%B2%D1%82%D0%BE%D0%BC%D0%BE%D0%B1%D0%B8%D0%BB%D1%8C.jpg", disposition.utf8_filename
      assert_equal "inline; #{disposition.ascii_filename}; #{disposition.utf8_filename}", disposition.to_s
    end

    test "encoding a filename with permitted chars" do
      disposition = Http::ContentDisposition.new(disposition: :inline, filename: "argh+!#$-123_|&^`~.jpg")

      assert_equal %(filename="argh+!\#$-123_|%26^`~.jpg"), disposition.ascii_filename
      assert_equal "filename*=UTF-8''argh+!\#$-123_|&^`~.jpg", disposition.utf8_filename
      assert_equal "inline; #{disposition.ascii_filename}; #{disposition.utf8_filename}", disposition.to_s
    end

    test "without filename" do
      disposition = Http::ContentDisposition.new(disposition: :inline, filename: nil)

      assert_equal "inline", disposition.to_s
    end

    test ".format builds the header string" do
      expected = Http::ContentDisposition.new(disposition: :inline, filename: "racecar.jpg").to_s

      assert_equal expected, Http::ContentDisposition.format(disposition: :inline, filename: "racecar.jpg")
    end

    test ".format without filename" do
      assert_equal "inline", Http::ContentDisposition.format(disposition: :inline, filename: nil)
    end

    test "strips CRLF injection from disposition" do
      disposition = Http::ContentDisposition.new(
        disposition: "attachment\r\nX-Evil: 1",
        filename: "report.pdf"
      )

      assert_equal "attachment", disposition.disposition
      assert_no_match(/[\r\n]/, disposition.to_s)
      assert_equal "attachment; #{disposition.ascii_filename}; #{disposition.utf8_filename}", disposition.to_s
    end

    test "strips quotes and truncates at first non-token character" do
      disposition = Http::ContentDisposition.new(
        disposition: %(attachment"; filename="evil),
        filename: "report.pdf"
      )

      assert_equal "attachment", disposition.disposition
    end

    test "falls back to attachment when disposition has no token characters" do
      disposition = Http::ContentDisposition.new(disposition: "\r\n\"\\", filename: nil)

      assert_equal "attachment", disposition.to_s
    end

    test ".format sanitizes disposition with CRLF" do
      header = Http::ContentDisposition.format(
        disposition: "inline\r\nSet-Cookie: a=b",
        filename: "a.txt"
      )

      assert_no_match(/[\r\n]/, header)
      assert_match(/\Ainline; /, header)
    end
  end
end
