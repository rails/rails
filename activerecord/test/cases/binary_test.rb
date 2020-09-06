# frozen_string_literal: true

require 'cases/helper'
require 'models/binary'

class BinaryTest < ActiveRecord::TestCase
  FIXTURES = %w(flowers.jpg example.log test.txt)

  def test_mixed_encoding
    str = +"\x80"
    str.force_encoding('ASCII-8BIT')

    binary = Binary.new name: 'いただきます！', data: str
    binary.save!
    binary.reload
    assert_equal str, binary.data

    name = binary.name

    assert_equal 'いただきます！', name
  end

  def test_load_save
    Binary.delete_all

    FIXTURES.each do |filename|
      data = File.read(ASSETS_ROOT + "/#{filename}")
      data.force_encoding('ASCII-8BIT')
      data.freeze

      bin = Binary.new(data: data)
      assert_equal data, bin.data, 'Newly assigned data differs from original'

      bin.save!
      assert_equal data, bin.data, 'Data differs from original after save'

      assert_equal data, bin.reload.data, 'Reloaded data differs from original'
    end
  end
end
