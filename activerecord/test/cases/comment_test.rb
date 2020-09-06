# frozen_string_literal: true

require 'cases/helper'
require 'support/schema_dumping_helper'

if ActiveRecord::Base.connection.supports_comments?
  class CommentTest < ActiveRecord::TestCase
    include SchemaDumpingHelper

    class Commented < ActiveRecord::Base
      self.table_name = 'commenteds'
    end

    class BlankComment < ActiveRecord::Base
    end

    class PkCommented < ActiveRecord::Base
    end

    setup do
      @connection = ActiveRecord::Base.connection

      @connection.create_table('commenteds', comment: 'A table with comment', force: true) do |t|
        t.string  'name',    comment: 'Comment should help clarify the column purpose'
        t.boolean 'obvious', comment: 'Question is: should you comment obviously named objects?'
        t.string  'content'
        t.index   'name',    comment: %Q["Very important" index that powers all the performance.\nAnd it's fun!]
      end

      @connection.create_table('blank_comments', comment: ' ', force: true) do |t|
        t.string :space_comment, comment: ' '
        t.string :empty_comment, comment: ''
        t.string :nil_comment, comment: nil
        t.string :absent_comment
        t.index :space_comment, comment: ' '
        t.index :empty_comment, comment: ''
        t.index :nil_comment, comment: nil
        t.index :absent_comment
      end

      @connection.create_table('pk_commenteds', comment: 'Table comment', id: false, force: true) do |t|
        t.primary_key :id, comment: 'Primary key comment'
      end

      Commented.reset_column_information
      BlankComment.reset_column_information
      PkCommented.reset_column_information
    end

    teardown do
      @connection.drop_table 'commenteds', if_exists: true
      @connection.drop_table 'blank_comments', if_exists: true
    end

    def test_default_primary_key_comment
      column = Commented.columns_hash['id']
      assert_nil column.comment
    end

    def test_column_created_in_block
      column = Commented.columns_hash['name']
      assert_equal :string, column.type
      assert_equal 'Comment should help clarify the column purpose', column.comment
    end

    def test_blank_columns_created_in_block
      %w[ space_comment empty_comment nil_comment absent_comment ].each do |field|
        column = BlankComment.columns_hash[field]
        assert_equal :string, column.type
        assert_nil column.comment
      end
    end

    def test_blank_indexes_created_in_block
      @connection.indexes('blank_comments').each do |index|
        assert_nil index.comment
      end
    end

    def test_add_column_with_comment_later
      @connection.add_column :commenteds, :rating, :integer, comment: 'I am running out of imagination'
      Commented.reset_column_information
      column = Commented.columns_hash['rating']

      assert_equal :integer, column.type
      assert_equal 'I am running out of imagination', column.comment
    end

    def test_add_index_with_comment_later
      unless current_adapter?(:OracleAdapter)
        @connection.add_index :commenteds, :obvious, name: 'idx_obvious', comment: 'We need to see obvious comments'
        index = @connection.indexes('commenteds').find { |idef| idef.name == 'idx_obvious' }
        assert_equal 'We need to see obvious comments', index.comment
      end
    end

    def test_add_comment_to_column
      @connection.change_column :commenteds, :content, :string, comment: 'Whoa, content describes itself!'

      Commented.reset_column_information
      column = Commented.columns_hash['content']

      assert_equal :string, column.type
      assert_equal 'Whoa, content describes itself!', column.comment
    end

    def test_remove_comment_from_column
      @connection.change_column :commenteds, :obvious, :string, comment: nil

      Commented.reset_column_information
      column = Commented.columns_hash['obvious']

      assert_equal :string, column.type
      assert_nil column.comment
    end

    def test_rename_column_preserves_comment
      @connection.add_column    :commenteds, :rating, :string, comment: 'I am running out of imagination'
      @connection.rename_column :commenteds, :rating, :new_rating

      Commented.reset_column_information
      column = Commented.columns_hash['new_rating']

      assert_equal :string, column.type
      assert_equal column.comment, 'I am running out of imagination'
    end

    def test_schema_dump_with_comments
      # Do all the stuff from other tests
      @connection.add_column    :commenteds, :rating, :integer, comment: 'I am running out of imagination'
      @connection.change_column :commenteds, :content, :string, comment: 'Whoa, content describes itself!'
      @connection.change_column :commenteds, :content, :string
      @connection.change_column :commenteds, :obvious, :string, comment: nil
      @connection.add_index     :commenteds, :obvious, name: 'idx_obvious', comment: 'We need to see obvious comments'

      # And check that these changes are reflected in dump
      output = dump_table_schema 'commenteds'
      assert_match %r[create_table "commenteds",.*\s+comment: "A table with comment"], output
      assert_match %r[t\.string\s+"name",\s+comment: "Comment should help clarify the column purpose"], output
      assert_match %r[t\.string\s+"obvious"\n], output
      assert_match %r[t\.string\s+"content",\s+comment: "Whoa, content describes itself!"], output
      if current_adapter?(:OracleAdapter)
        assert_match %r[t\.integer\s+"rating",\s+precision: 38,\s+comment: "I am running out of imagination"], output
      else
        assert_match %r[t\.integer\s+"rating",\s+comment: "I am running out of imagination"], output
        assert_match %r[t\.index\s+.+\s+comment: "\\\"Very important\\\" index that powers all the performance.\\nAnd it's fun!"], output
        assert_match %r[t\.index\s+.+\s+name: "idx_obvious",\s+comment: "We need to see obvious comments"], output
      end
    end

    def test_schema_dump_omits_blank_comments
      output = dump_table_schema 'blank_comments'

      assert_match %r[create_table "blank_comments"], output
      assert_no_match %r[create_table "blank_comments",.+comment:], output

      assert_match %r[t\.string\s+"space_comment"\n], output
      assert_no_match %r[t\.string\s+"space_comment", comment:\n], output

      assert_match %r[t\.string\s+"empty_comment"\n], output
      assert_no_match %r[t\.string\s+"empty_comment", comment:\n], output

      assert_match %r[t\.string\s+"nil_comment"\n], output
      assert_no_match %r[t\.string\s+"nil_comment", comment:\n], output

      assert_match %r[t\.string\s+"absent_comment"\n], output
      assert_no_match %r[t\.string\s+"absent_comment", comment:\n], output
    end

    def test_change_table_comment
      @connection.change_table_comment :commenteds, 'Edited table comment'
      assert_equal 'Edited table comment', @connection.table_comment('commenteds')
    end

    def test_change_table_comment_to_nil
      @connection.change_table_comment :commenteds, nil
      assert_nil @connection.table_comment('commenteds')
    end

    def test_change_column_comment
      @connection.change_column_comment :commenteds, :name, 'Edited column comment'
      column = Commented.columns_hash['name']
      assert_equal 'Edited column comment', column.comment
    end

    def test_change_column_comment_to_nil
      @connection.change_column_comment :commenteds, :name, nil
      column = Commented.columns_hash['name']
      assert_nil column.comment
    end

    def test_comment_on_primary_key
      column = PkCommented.columns_hash['id']
      assert_equal 'Primary key comment', column.comment
      assert_equal 'Table comment', @connection.table_comment('pk_commenteds')
    end

    def test_schema_dump_with_primary_key_comment
      output = dump_table_schema 'pk_commenteds'
      assert_match %r[create_table "pk_commenteds", id: { comment: "Primary key comment" }.*, comment: "Table comment"], output
    end
  end
end
