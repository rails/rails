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

    test "without filename" do
      disposition = Http::ContentDisposition.new(disposition: :inline, filename: nil)

      assert_equal "inline", disposition.to_s
    end
  end
end
