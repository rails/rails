require "cases/helper"

module ActiveRecord
  class Migration
    class CreateJoinTableTest < ActiveRecord::TestCase
      attr_reader :connection

      def setup
        super
        @connection = ActiveRecord::Base.connection
      end

      teardown do
        %w(artists_musics musics_videos catalog).each do |table_name|
          ActiveSupport::Deprecation.silence do
            connection.drop_table table_name if connection.table_exists?(table_name)
          end
        end
      end

      def test_create_join_table
        connection.create_join_table :artists, :musics

        assert_equal %w(artist_id music_id), connection.columns(:artists_musics).map(&:name).sort
      end

      def test_create_join_table_set_not_null_by_default
        connection.create_join_table :artists, :musics

        assert_equal [false, false], connection.columns(:artists_musics).map(&:null)
      end

      def test_create_join_table_with_strings
        connection.create_join_table "artists", "musics"

        assert_equal %w(artist_id music_id), connection.columns(:artists_musics).map(&:name).sort
      end

      def test_create_join_table_with_symbol_and_string
        connection.create_join_table :artists, "musics"

        assert_equal %w(artist_id music_id), connection.columns(:artists_musics).map(&:name).sort
      end

      def test_create_join_table_with_the_proper_order
        connection.create_join_table :videos, :musics

        assert_equal %w(music_id video_id), connection.columns(:musics_videos).map(&:name).sort
      end

      def test_create_join_table_with_the_table_name
        connection.create_join_table :artists, :musics, table_name: :catalog

        assert_equal %w(artist_id music_id), connection.columns(:catalog).map(&:name).sort
      end

      def test_create_join_table_with_the_table_name_as_string
        connection.create_join_table :artists, :musics, table_name: "catalog"

        assert_equal %w(artist_id music_id), connection.columns(:catalog).map(&:name).sort
      end

      def test_create_join_table_with_column_options
        connection.create_join_table :artists, :musics, column_options: { null: true }

        assert_equal [true, true], connection.columns(:artists_musics).map(&:null)
      end

      def test_create_join_table_without_indexes
        connection.create_join_table :artists, :musics

        assert connection.indexes(:artists_musics).blank?
      end

      def test_create_join_table_with_index
        connection.create_join_table :artists, :musics do |t|
          t.index [:artist_id, :music_id]
        end

        assert_equal [%w(artist_id music_id)], connection.indexes(:artists_musics).map(&:columns)
      end

      def test_drop_join_table
        connection.create_join_table :artists, :musics
        connection.drop_join_table :artists, :musics

        ActiveSupport::Deprecation.silence { assert !connection.table_exists?("artists_musics") }
      end

      def test_drop_join_table_with_strings
        connection.create_join_table :artists, :musics
        connection.drop_join_table "artists", "musics"

        ActiveSupport::Deprecation.silence { assert !connection.table_exists?("artists_musics") }
      end

      def test_drop_join_table_with_the_proper_order
        connection.create_join_table :videos, :musics
        connection.drop_join_table :videos, :musics

        ActiveSupport::Deprecation.silence { assert !connection.table_exists?("musics_videos") }
      end

      def test_drop_join_table_with_the_table_name
        connection.create_join_table :artists, :musics, table_name: :catalog
        connection.drop_join_table :artists, :musics, table_name: :catalog

        ActiveSupport::Deprecation.silence { assert !connection.table_exists?("catalog") }
      end

      def test_drop_join_table_with_the_table_name_as_string
        connection.create_join_table :artists, :musics, table_name: "catalog"
        connection.drop_join_table :artists, :musics, table_name: "catalog"

        ActiveSupport::Deprecation.silence { assert !connection.table_exists?("catalog") }
      end

      def test_drop_join_table_with_column_options
        connection.create_join_table :artists, :musics, column_options: { null: true }
        connection.drop_join_table :artists, :musics, column_options: { null: true }

        ActiveSupport::Deprecation.silence { assert !connection.table_exists?("artists_musics") }
      end

      def test_create_and_drop_join_table_with_common_prefix
        with_table_cleanup do
          connection.create_join_table "audio_artists", "audio_musics"
          ActiveSupport::Deprecation.silence { assert connection.table_exists?("audio_artists_musics") }

          connection.drop_join_table "audio_artists", "audio_musics"
          ActiveSupport::Deprecation.silence { assert !connection.table_exists?("audio_artists_musics"), "Should have dropped join table, but didn't" }
        end
      end

      if current_adapter?(:PostgreSQLAdapter)
        def test_create_join_table_with_uuid
          connection.create_join_table :artists, :musics, column_options: { type: :uuid }
          assert_equal [:uuid, :uuid], connection.columns(:artists_musics).map(&:type)
        end
      end

      private

        def with_table_cleanup
          tables_before = connection.data_sources

          yield
        ensure
          tables_after = connection.data_sources - tables_before

          tables_after.each do |table|
            connection.drop_table table
          end
        end
    end
  end
end
