# frozen_string_literal: true

require "cases/helper"
require "models/binary"

class BinaryTest < ActiveRecord::TestCase
  FIXTURES = %w(flowers.jpg example.log test.txt)

  def test_mixed_encoding
    str = +"\x80"
    str.force_encoding("ASCII-8BIT")

    binary = Binary.new name: "いただきます！", data: str
    binary.save!
    binary.reload
    assert_equal str, binary.data

    name = binary.name

    assert_equal "いただきます！", name
  end

  def test_load_save
    Binary.delete_all

    FIXTURES.each do |filename|
      data = File.read(ASSETS_ROOT + "/#{filename}")
      data.force_encoding("ASCII-8BIT")
      data.freeze

      bin = Binary.new(data: data)
      assert_equal data, bin.data, "Newly assigned data differs from original"

      bin.save!
      assert_equal data, bin.data, "Data differs from original after save"

      assert_equal data, bin.reload.data, "Reloaded data differs from original"
    end
  end

  def test_unicode_input_casting
    binary = Binary.new(name: 123, data: "text")

    # Before saving, attribute methods return casted values, but their
    # _before_type_cast still returns the original value. (Integer-to-String
    # conversion used for comparison.)
    assert_equal "123", binary.name
    assert_equal 123, binary.name_before_type_cast
    assert_equal Encoding::BINARY, binary.data.encoding
    assert_equal Encoding::UTF_8, binary.data_before_type_cast.to_s.encoding

    binary.save!

    # After saving, casted values appear throughout.
    assert_equal "123", binary.name
    assert_equal "123", binary.name_before_type_cast
    assert_equal Encoding::BINARY, binary.data.encoding
    assert_equal Encoding::BINARY, binary.data_before_type_cast.to_s.encoding

    binary.reload

    assert_equal "123", binary.name
    assert_equal "123", binary.name_before_type_cast
    assert_equal Encoding::BINARY, binary.data.encoding
    # After reloading, data_before_type_cast is adapter-dependent. For
    # example, PostgreSQL returns the bytea_output encoded representation,
    # which happens to be UTF-8.
  end
end
