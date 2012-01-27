require 'cases/helper'

module ActiveRecord
  class Migration
    class CreateJoinTableTest < ActiveRecord::TestCase
      attr_reader :connection

      def setup
        super
        @connection = ActiveRecord::Base.connection
      end

      def test_create_join_table
        connection.create_join_table :artists, :musics

        assert_equal %w(artist_id music_id), connection.columns(:artists_musics).map(&:name).sort
      ensure
        connection.drop_table :artists_musics
      end

      def test_create_join_table_set_not_null_by_default
        connection.create_join_table :artists, :musics

        assert_equal [false, false], connection.columns(:artists_musics).map(&:null)
      ensure
        connection.drop_table :artists_musics
      end

      def test_create_join_table_with_strings
        connection.create_join_table 'artists', 'musics'

        assert_equal %w(artist_id music_id), connection.columns(:artists_musics).map(&:name).sort
      ensure
        connection.drop_table :artists_musics
      end

      def test_create_join_table_with_the_proper_order
        connection.create_join_table :videos, :musics

        assert_equal %w(music_id video_id), connection.columns(:musics_videos).map(&:name).sort
      ensure
        connection.drop_table :musics_videos
      end

      def test_create_join_table_with_the_table_name
        connection.create_join_table :artists, :musics, :table_name => :catalog

        assert_equal %w(artist_id music_id), connection.columns(:catalog).map(&:name).sort
      ensure
        connection.drop_table :catalog
      end

      def test_create_join_table_with_the_table_name_as_string
        connection.create_join_table :artists, :musics, :table_name => 'catalog'

        assert_equal %w(artist_id music_id), connection.columns(:catalog).map(&:name).sort
      ensure
        connection.drop_table :catalog
      end

      def test_create_join_table_with_column_options
        connection.create_join_table :artists, :musics, :column_options => {:null => true}

        assert_equal [true, true], connection.columns(:artists_musics).map(&:null)
      ensure
        connection.drop_table :artists_musics
      end
    end
  end
end
