require "cases/helper"

module ActiveRecord
  class ResultTest < ActiveRecord::TestCase
    def result
      Result.new(['col_1', 'col_2'], [
        ['row 1 col 1', 'row 1 col 2'],
        ['row 2 col 1', 'row 2 col 2']
      ])
    end

    def test_to_hash_returns_row_hashes
      assert_equal [
        {'col_1' => 'row 1 col 1', 'col_2' => 'row 1 col 2'},
        {'col_1' => 'row 2 col 1', 'col_2' => 'row 2 col 2'}
      ], result.to_hash
    end

    def test_each_with_block_returns_row_hashes
      result.each do |row|
        assert_equal ['col_1', 'col_2'], row.keys
      end
    end

    def test_each_without_block_returns_an_enumerator
      result.each.with_index do |row, index|
        assert_equal ['col_1', 'col_2'], row.keys
        assert_kind_of Integer, index
      end
    end
  end
end
