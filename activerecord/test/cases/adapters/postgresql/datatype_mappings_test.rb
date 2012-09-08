require "cases/helper"

class PostgresqlDataTypeMappingsTest < ActiveRecord::TestCase

  def test_arrays_are_represented_as_string
    assert_postgres_sql_type_is_represented_as('integer[]', :string)
    assert_postgres_sql_type_is_represented_as('text[]', :string)
    assert_postgres_sql_type_is_represented_as('character[][]', :string)
  end

  def test_bigint_is_represented_as_integer
    assert_postgres_sql_type_is_represented_as('bigint', :integer)
  end

  def test_bit_is_represented_as_string
    assert_postgres_sql_type_is_represented_as('bit', :string)
    assert_postgres_sql_type_is_represented_as('bit(10)', :string)
    assert_postgres_sql_type_is_represented_as('bit varying', :string)
    assert_postgres_sql_type_is_represented_as('bit varying(7)', :string)
  end

  def test_boolean_is_represented_as_boolean
    assert_postgres_sql_type_is_represented_as('boolean', :boolean)
    # currently not handled
    # assert_postgres_sql_type_is_represented_as('bool', :boolean)
  end

  def test_geometric_types_are_represented_as_string
    assert_postgres_sql_type_is_represented_as('box', :string)
    assert_postgres_sql_type_is_represented_as('circle', :string)
    assert_postgres_sql_type_is_represented_as('polygon', :string)
    assert_postgres_sql_type_is_represented_as('line', :string)
    assert_postgres_sql_type_is_represented_as('point', :string)
    assert_postgres_sql_type_is_represented_as('lseg', :string)
    assert_postgres_sql_type_is_represented_as('path', :string)
  end

  def test_bytea_is_represented_as_binary
    assert_postgres_sql_type_is_represented_as('bytea', :binary)
  end

  def test_varchar_is_represented_as_string
    assert_postgres_sql_type_is_represented_as('character varying', :string)
    assert_postgres_sql_type_is_represented_as('character varying(20)', :string)
    assert_postgres_sql_type_is_represented_as('varchar', :string)
    assert_postgres_sql_type_is_represented_as('varchar(255)', :string)
  end

  def test_character_is_represented_as_string
    assert_postgres_sql_type_is_represented_as('character(23)', :string)
    assert_postgres_sql_type_is_represented_as('char', :string)
    assert_postgres_sql_type_is_represented_as('char(2)', :string)
  end

  def test_cidr_is_represented_as_cidr
    assert_postgres_sql_type_is_represented_as('cidr', :cidr)
  end

  def test_date_is_represented_as_date
    assert_postgres_sql_type_is_represented_as('date', :date)
  end

  def test_double_precision_is_represented_as_float
    assert_postgres_sql_type_is_represented_as('double precision', :float)
    assert_postgres_sql_type_is_represented_as('float8', :float)
    assert_postgres_sql_type_is_represented_as('float', :float)
  end

  def test_inet_is_represented_as_inet
    assert_postgres_sql_type_is_represented_as('inet', :inet)
  end

  def test_ineger_is_represented_as_integer
    assert_postgres_sql_type_is_represented_as('integer', :integer)
    assert_postgres_sql_type_is_represented_as('int', :integer)
    assert_postgres_sql_type_is_represented_as('int4', :integer)
  end

  def test_interval_is_represented_as_string
    assert_postgres_sql_type_is_represented_as('interval', :string)
    assert_postgres_sql_type_is_represented_as('interval(34)', :string)
  end

  def test_json_is_represented_as_json
    assert_postgres_sql_type_is_represented_as('json', :json)
  end

  def test_macaddr_is_represented_as_macaddr
    assert_postgres_sql_type_is_represented_as('macaddr', :macaddr)
  end

  def test_money_is_represented_as_decimal
    assert_postgres_sql_type_is_represented_as('money', :decimal)
  end

  def test_numerics_are_represented_as_decimal
    assert_postgres_sql_type_is_represented_as('decimal', :decimal)
    assert_postgres_sql_type_is_represented_as('numeric(4, 2)', :decimal)
    assert_postgres_sql_type_is_represented_as('decimal(10, 3)', :decimal)
    assert_postgres_sql_type_is_represented_as('numeric(4, 0)', :decimal)
    assert_postgres_sql_type_is_represented_as('decimal(9, 0)', :decimal)
  end

  def test_oid_is_represented_as_integer
    assert_postgres_sql_type_is_represented_as('oid', :integer)
  end

  def test_real_is_represented_as_float
    assert_postgres_sql_type_is_represented_as('real', :float)
    assert_postgres_sql_type_is_represented_as('float4', :float)
  end

  def test_smallint_is_represented_as_integer
    assert_postgres_sql_type_is_represented_as('smallint', :integer)
    assert_postgres_sql_type_is_represented_as('int2', :integer)
  end

  def test_text_is_represented_as_text
    assert_postgres_sql_type_is_represented_as('text', :text)
  end

  def test_time_without_time_zone_is_represented_as_time
    assert_postgres_sql_type_is_represented_as('time', :time)
    assert_postgres_sql_type_is_represented_as('time without time zone', :time)
  end

  def test_time_with_time_zone_is_represented_as_time
    assert_postgres_sql_type_is_represented_as('time with time zone', :time)
    assert_postgres_sql_type_is_represented_as('timetz', :time)
  end

  def test_timestamp_without_time_zone_is_represented_as_datetime
    # BUG: currently translates to timestamp
    # assert_postgres_sql_type_is_represented_as('timestamp', :datetime)

    assert_postgres_sql_type_is_represented_as('timestamp without time zone', :datetime)
  end

  def test_timestamp_with_time_zone_is_represented_as_datetime
    assert_postgres_sql_type_is_represented_as('timestamp with time zone', :datetime)
    # BUG: currently translates to timestamp
    # assert_postgres_sql_type_is_represented_as('timestamptz', :datetime)
  end

  def test_tsquery_is_not_supported
    assert_postgres_sql_type_is_represented_as('tsquery', nil)
  end

  def test_tsvector_is_represented_as_tsvector
    assert_postgres_sql_type_is_represented_as('tsvector', :tsvector)
  end

  def test_xml_is_represented_as_xml
    assert_postgres_sql_type_is_represented_as('xml', :xml)
  end

  def test_hstore_is_represented_as_hstore
    assert_postgres_sql_type_is_represented_as('hstore', :hstore)
  end

  def test_uuid_is_represented_as_uuid
    assert_postgres_sql_type_is_represented_as('uuid', :uuid)
  end

  def test_txid_snapshot_is_not_supported
    assert_postgres_sql_type_is_represented_as('txid_snapshot', nil)
  end

  private
  def assert_postgres_sql_type_is_represented_as(sql_type, representation_type)
    column = ActiveRecord::ConnectionAdapters::PostgreSQLColumn.new("column(#{sql_type})", nil, nil, sql_type)
    assert_equal representation_type, column.type, "postgres sql type '#{sql_type}' should be represented as '#{representation_type}' but was '#{column.type}'"
  end
end
