# encoding: utf-8

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class MysqlAdapterTest < ActiveRecord::TestCase
      def setup
        @conn = ActiveRecord::Base.connection
        @conn.exec_query('drop table if exists ex')
        @conn.exec_query(<<-eosql)
          CREATE TABLE `ex` (
            `id` int(11) DEFAULT NULL auto_increment PRIMARY KEY,
            `number` integer,
            `data` varchar(255))
        eosql
      end

      def test_client_encoding
        if "<3".respond_to?(:encoding)
          assert_equal Encoding::UTF_8, @conn.client_encoding
        else
          assert_equal 'utf8', @conn.client_encoding
        end
      end

      def test_exec_insert_number
        insert(@conn, 'number' => 10)

        result = @conn.exec_query('SELECT number FROM ex WHERE number = 10')

        assert_equal 1, result.rows.length
        # if there are no bind parameters, it will return a string (due to
        # the libmysql api)
        assert_equal '10', result.rows.last.last
      end

      def test_exec_insert_string
        str = 'いただきます！'
        insert(@conn, 'number' => 10, 'data' => str)

        result = @conn.exec_query('SELECT number, data FROM ex WHERE number = 10')

        value = result.rows.last.last

        if "<3".respond_to?(:encoding)
          # FIXME: this should probably be inside the mysql AR adapter?
          value.force_encoding(@conn.client_encoding)

          # The strings in this file are utf-8, so transcode to utf-8
          value.encode!(Encoding::UTF_8)
        end

        assert_equal str, value
      end

      def test_pk_and_sequence_for
        pk, seq = @conn.pk_and_sequence_for('ex')
        assert_equal 'id', pk
        assert_equal @conn.default_sequence_name('ex', 'id'), seq
      end

      def test_pk_and_sequence_for_with_non_standard_primary_key
        @conn.exec_query('drop table if exists ex_with_non_standard_pk')
        @conn.exec_query(<<-eosql)
          CREATE TABLE `ex_with_non_standard_pk` (
            `code` INT(11) DEFAULT NULL auto_increment,
             PRIMARY KEY  (`code`))
        eosql
        pk, seq = @conn.pk_and_sequence_for('ex_with_non_standard_pk')
        assert_equal 'code', pk
        assert_equal @conn.default_sequence_name('ex_with_non_standard_pk', 'code'), seq
      end

      def test_pk_and_sequence_for_with_custom_index_type_pk
        @conn.exec_query('drop table if exists ex_with_custom_index_type_pk')
        @conn.exec_query(<<-eosql)
          CREATE TABLE `ex_with_custom_index_type_pk` (
            `id` INT(11) DEFAULT NULL auto_increment,
             PRIMARY KEY  USING BTREE (`id`))
        eosql
        pk, seq = @conn.pk_and_sequence_for('ex_with_custom_index_type_pk')
        assert_equal 'id', pk
        assert_equal @conn.default_sequence_name('ex_with_custom_index_type_pk', 'id'), seq
      end

      def test_tables_quoting
        begin
          @conn.tables(nil, "foo-bar", nil)
          flunk
        rescue => e
          # assertion for *quoted* database properly
          assert_match(/database 'foo-bar'/, e.inspect)
        end
      end

      private
      def insert(ctx, data)
        binds   = data.map { |name, value|
          [ctx.columns('ex').find { |x| x.name == name }, value]
        }
        columns = binds.map(&:first).map(&:name)

        sql = "INSERT INTO ex (#{columns.join(", ")})
               VALUES (#{(['?'] * columns.length).join(', ')})"

        ctx.exec_insert(sql, 'SQL', binds)
      end
    end
  end
end
