require "cases/helper"

class PostgresqlArray < ActiveRecord::Base
end

class PostgresqlTsvector < ActiveRecord::Base
end

class PostgresqlMoney < ActiveRecord::Base
end

class PostgresqlNumber < ActiveRecord::Base
end

class PostgresqlTime < ActiveRecord::Base
end

class PostgresqlNetworkAddress < ActiveRecord::Base
end

class PostgresqlBitString < ActiveRecord::Base
end

class PostgresqlOid < ActiveRecord::Base
end

class PostgresqlTimestampWithZone < ActiveRecord::Base
end

class PostgresqlUUID < ActiveRecord::Base
end

class PostgresqlLtree < ActiveRecord::Base
end

class PostgresqlDataTypeTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.execute("set lc_monetary = 'C'")

    @connection.execute("INSERT INTO postgresql_arrays (id, commission_by_quarter, nicknames) VALUES (1, '{35000,21000,18000,17000}', '{foo,bar,baz}')")
    @first_array = PostgresqlArray.find(1)

    @connection.execute("INSERT INTO postgresql_tsvectors (id, text_vector) VALUES (1, ' ''text'' ''vector'' ')")

    @first_tsvector = PostgresqlTsvector.find(1)

    @connection.execute("INSERT INTO postgresql_moneys (id, wealth) VALUES (1, '567.89'::money)")
    @connection.execute("INSERT INTO postgresql_moneys (id, wealth) VALUES (2, '-567.89'::money)")
    @first_money = PostgresqlMoney.find(1)
    @second_money = PostgresqlMoney.find(2)

    @connection.execute("INSERT INTO postgresql_numbers (id, single, double) VALUES (1, 123.456, 123456.789)")
    @connection.execute("INSERT INTO postgresql_numbers (id, single, double) VALUES (2, '-Infinity', 'Infinity')")
    @connection.execute("INSERT INTO postgresql_numbers (id, single, double) VALUES (3, 123.456, 'NaN')")
    @first_number = PostgresqlNumber.find(1)
    @second_number = PostgresqlNumber.find(2)
    @third_number = PostgresqlNumber.find(3)

    @connection.execute("INSERT INTO postgresql_times (id, time_interval, scaled_time_interval) VALUES (1, '1 year 2 days ago', '3 weeks ago')")
    @first_time = PostgresqlTime.find(1)

    @connection.execute("INSERT INTO postgresql_network_addresses (id, cidr_address, inet_address, mac_address) VALUES(1, '192.168.0/24', '172.16.1.254/32', '01:23:45:67:89:0a')")
    @first_network_address = PostgresqlNetworkAddress.find(1)

    @connection.execute("INSERT INTO postgresql_bit_strings (id, bit_string, bit_string_varying) VALUES (1, B'00010101', X'15')")
    @first_bit_string = PostgresqlBitString.find(1)

    @connection.execute("INSERT INTO postgresql_oids (id, obj_id) VALUES (1, 1234)")
    @first_oid = PostgresqlOid.find(1)

    @connection.execute("INSERT INTO postgresql_timestamp_with_zones (id, time) VALUES (1, '2010-01-01 10:00:00-1')")

    @connection.execute("INSERT INTO postgresql_uuids (id, guid, compact_guid) VALUES(1, 'd96c3da0-96c1-012f-1316-64ce8f32c6d8', 'f06c715096c1012f131764ce8f32c6d8')")
    @first_uuid = PostgresqlUUID.find(1)
  end

  def teardown
    [PostgresqlArray, PostgresqlTsvector, PostgresqlMoney, PostgresqlNumber, PostgresqlTime, PostgresqlNetworkAddress,
     PostgresqlBitString, PostgresqlOid, PostgresqlTimestampWithZone, PostgresqlUUID].each(&:delete_all)
  end

  def test_array_escaping
    unknown = %(foo\\",bar,baz,\\)
    nicknames = ["hello_#{unknown}"]
    ar = PostgresqlArray.create!(nicknames: nicknames, id: 100)
    ar.reload
    assert_equal nicknames, ar.nicknames
  end

  def test_data_type_of_array_types
    assert_equal :integer, @first_array.column_for_attribute(:commission_by_quarter).type
    assert_equal :text, @first_array.column_for_attribute(:nicknames).type
  end

  def test_data_type_of_tsvector_types
    assert_equal :tsvector, @first_tsvector.column_for_attribute(:text_vector).type
  end

  def test_data_type_of_money_types
    assert_equal :decimal, @first_money.column_for_attribute(:wealth).type
  end

  def test_data_type_of_number_types
    assert_equal :float, @first_number.column_for_attribute(:single).type
    assert_equal :float, @first_number.column_for_attribute(:double).type
  end

  def test_data_type_of_time_types
    assert_equal :string, @first_time.column_for_attribute(:time_interval).type
    assert_equal :string, @first_time.column_for_attribute(:scaled_time_interval).type
  end

  def test_data_type_of_network_address_types
    assert_equal :cidr, @first_network_address.column_for_attribute(:cidr_address).type
    assert_equal :inet, @first_network_address.column_for_attribute(:inet_address).type
    assert_equal :macaddr, @first_network_address.column_for_attribute(:mac_address).type
  end

  def test_data_type_of_bit_string_types
    assert_equal :string, @first_bit_string.column_for_attribute(:bit_string).type
    assert_equal :string, @first_bit_string.column_for_attribute(:bit_string_varying).type
  end

  def test_data_type_of_oid_types
    assert_equal :integer, @first_oid.column_for_attribute(:obj_id).type
  end

  def test_data_type_of_uuid_types
    assert_equal :uuid, @first_uuid.column_for_attribute(:guid).type
  end

  def test_array_values
   assert_equal [35000,21000,18000,17000], @first_array.commission_by_quarter
   assert_equal ['foo','bar','baz'], @first_array.nicknames
  end

  def test_tsvector_values
    assert_equal "'text' 'vector'", @first_tsvector.text_vector
  end

  def test_money_values
    assert_equal 567.89, @first_money.wealth
    assert_equal(-567.89, @second_money.wealth)
  end

  def test_money_type_cast
    column = PostgresqlMoney.columns.find { |c| c.name == 'wealth' }
    assert_equal(12345678.12, column.type_cast("$12,345,678.12"))
    assert_equal(12345678.12, column.type_cast("$12.345.678,12"))
    assert_equal(-1.15, column.type_cast("-$1.15"))
    assert_equal(-2.25, column.type_cast("($2.25)"))
  end

  def test_update_tsvector
    new_text_vector = "'new' 'text' 'vector'"
    @first_tsvector.text_vector = new_text_vector
    assert @first_tsvector.save
    assert @first_tsvector.reload
    @first_tsvector.text_vector = new_text_vector
    assert @first_tsvector.save
    assert @first_tsvector.reload
    assert_equal new_text_vector, @first_tsvector.text_vector
  end

  def test_number_values
    assert_equal(123.456, @first_number.single)
    assert_equal(123456.789, @first_number.double)
    assert_equal(-::Float::INFINITY, @second_number.single)
    assert_equal(::Float::INFINITY, @second_number.double)
    assert_same(::Float::NAN, @third_number.double)
  end

  def test_time_values
    assert_equal '-1 years -2 days', @first_time.time_interval
    assert_equal '-21 days', @first_time.scaled_time_interval
  end

  def test_network_address_values_ipaddr
    cidr_address = IPAddr.new '192.168.0.0/24'
    inet_address = IPAddr.new '172.16.1.254'

    assert_equal cidr_address, @first_network_address.cidr_address
    assert_equal inet_address, @first_network_address.inet_address
    assert_equal '01:23:45:67:89:0a', @first_network_address.mac_address
  end

  def test_uuid_values
    assert_equal 'd96c3da0-96c1-012f-1316-64ce8f32c6d8', @first_uuid.guid
    assert_equal 'f06c7150-96c1-012f-1317-64ce8f32c6d8', @first_uuid.compact_guid
  end

  def test_bit_string_values
    assert_equal '00010101', @first_bit_string.bit_string
    assert_equal '00010101', @first_bit_string.bit_string_varying
  end

  def test_oid_values
    assert_equal 1234, @first_oid.obj_id
  end

  def test_update_integer_array
    new_value = [32800,95000,29350,17000]
    @first_array.commission_by_quarter = new_value
    assert @first_array.save
    assert @first_array.reload
    assert_equal new_value, @first_array.commission_by_quarter
    @first_array.commission_by_quarter = new_value
    assert @first_array.save
    assert @first_array.reload
    assert_equal new_value, @first_array.commission_by_quarter
  end

  def test_update_text_array
    new_value = ['robby','robert','rob','robbie']
    @first_array.nicknames = new_value
    assert @first_array.save
    assert @first_array.reload
    assert_equal new_value, @first_array.nicknames
    @first_array.nicknames = new_value
    assert @first_array.save
    assert @first_array.reload
    assert_equal new_value, @first_array.nicknames
  end

  def test_update_money
    new_value = BigDecimal.new('123.45')
    @first_money.wealth = new_value
    assert @first_money.save
    assert @first_money.reload
    assert_equal new_value, @first_money.wealth
  end

  def test_update_number
    new_single = 789.012
    new_double = 789012.345
    @first_number.single = new_single
    @first_number.double = new_double
    assert @first_number.save
    assert @first_number.reload
    assert_equal new_single, @first_number.single
    assert_equal new_double, @first_number.double
  end

  def test_update_time
    @first_time.time_interval = '2 years 3 minutes'
    assert @first_time.save
    assert @first_time.reload
    assert_equal '2 years 00:03:00', @first_time.time_interval
  end

  def test_update_network_address
    new_inet_address = '10.1.2.3/32'
    new_cidr_address = '10.0.0.0/8'
    new_mac_address = 'bc:de:f0:12:34:56'
    @first_network_address.cidr_address = new_cidr_address
    @first_network_address.inet_address = new_inet_address
    @first_network_address.mac_address = new_mac_address
    assert @first_network_address.save
    assert @first_network_address.reload
    assert_equal @first_network_address.cidr_address, new_cidr_address
    assert_equal @first_network_address.inet_address, new_inet_address
    assert_equal @first_network_address.mac_address, new_mac_address
  end

  def test_update_bit_string
    new_bit_string = '11111111'
    new_bit_string_varying = '0xFF'
    @first_bit_string.bit_string = new_bit_string
    @first_bit_string.bit_string_varying = new_bit_string_varying
    assert @first_bit_string.save
    assert @first_bit_string.reload
    assert_equal new_bit_string, @first_bit_string.bit_string
    assert_equal @first_bit_string.bit_string, @first_bit_string.bit_string_varying
  end

  def test_invalid_hex_string
    new_bit_string = 'FF'
    @first_bit_string.bit_string = new_bit_string
    assert_raise(ActiveRecord::StatementInvalid) { assert @first_bit_string.save }
  end

  def test_invalid_network_address
    @first_network_address.cidr_address = 'invalid addr'
    assert_nil @first_network_address.cidr_address
    assert_equal 'invalid addr', @first_network_address.cidr_address_before_type_cast
    assert @first_network_address.save

    @first_network_address.reload

    @first_network_address.inet_address = 'invalid addr'
    assert_nil @first_network_address.inet_address
    assert_equal 'invalid addr', @first_network_address.inet_address_before_type_cast
    assert @first_network_address.save
  end

  def test_update_oid
    new_value = 567890
    @first_oid.obj_id = new_value
    assert @first_oid.save
    assert @first_oid.reload
    assert_equal new_value, @first_oid.obj_id
  end

  def test_timestamp_with_zone_values_with_rails_time_zone_support
    with_timezone_config default: :utc, aware_attributes: true do
      @connection.reconnect!

      @first_timestamp_with_zone = PostgresqlTimestampWithZone.find(1)
      assert_equal Time.utc(2010,1,1, 11,0,0), @first_timestamp_with_zone.time
      assert_instance_of Time, @first_timestamp_with_zone.time
    end
  ensure
    @connection.reconnect!
  end

  def test_timestamp_with_zone_values_without_rails_time_zone_support
    with_timezone_config default: :local, aware_attributes: false do
      @connection.reconnect!
      # make sure to use a non-UTC time zone
      @connection.execute("SET time zone 'America/Jamaica'", 'SCHEMA')

      @first_timestamp_with_zone = PostgresqlTimestampWithZone.find(1)
      assert_equal Time.utc(2010,1,1, 11,0,0), @first_timestamp_with_zone.time
      assert_instance_of Time, @first_timestamp_with_zone.time
    end
  ensure
    @connection.reconnect!
  end
end
