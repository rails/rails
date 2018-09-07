# frozen_string_literal: true

require "test_helper"

class ActiveStorage::Filename::ParametersTest < ActiveSupport::TestCase
  test "parameterizing a Latin filename" do
    filename = ActiveStorage::Filename.new("racecar.jpg")

    assert_equal %(filename="racecar.jpg"), filename.parameters.ascii
    assert_equal "filename*=UTF-8''racecar.jpg", filename.parameters.utf8
    assert_equal "#{filename.parameters.ascii}; #{filename.parameters.utf8}", filename.parameters.combined
    assert_equal filename.parameters.combined, filename.parameters.to_s
  end

  test "parameterizing a Latin filename with accented characters" do
    filename = ActiveStorage::Filename.new("råcëçâr.jpg")

    assert_equal %(filename="racecar.jpg"), filename.parameters.ascii
    assert_equal "filename*=UTF-8''r%C3%A5c%C3%AB%C3%A7%C3%A2r.jpg", filename.parameters.utf8
    assert_equal "#{filename.parameters.ascii}; #{filename.parameters.utf8}", filename.parameters.combined
    assert_equal filename.parameters.combined, filename.parameters.to_s
  end

  test "parameterizing a non-Latin filename" do
    filename = ActiveStorage::Filename.new("автомобиль.jpg")

    assert_equal %(filename="%3F%3F%3F%3F%3F%3F%3F%3F%3F%3F.jpg"), filename.parameters.ascii
    assert_equal "filename*=UTF-8''%D0%B0%D0%B2%D1%82%D0%BE%D0%BC%D0%BE%D0%B1%D0%B8%D0%BB%D1%8C.jpg", filename.parameters.utf8
    assert_equal "#{filename.parameters.ascii}; #{filename.parameters.utf8}", filename.parameters.combined
    assert_equal filename.parameters.combined, filename.parameters.to_s
  end
end
