require "cases/helper"

class PostgresqlArray < ActiveRecord::Base
end

class PostgresqlRange < ActiveRecord::Base
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

    @connection.execute <<_SQL if @connection.supports_ranges?
    INSERT INTO postgresql_ranges (
      date_range,
      num_range,
      ts_range,
      tstz_range,
      int4_range,
      int8_range
    ) VALUES (
      '[''2012-01-02'', ''2012-01-04'']',
      '[0.1, 0.2]',
      '[''2010-01-01 14:30'', ''2011-01-01 14:30'']',
      '[''2010-01-01 14:30:00+05'', ''2011-01-01 14:30:00-03'']',
      '[1, 10]',
      '[10, 100]'
    )
_SQL

    @connection.execute <<_SQL if @connection.supports_ranges?
    INSERT INTO postgresql_ranges (
      date_range,
      num_range,
      ts_range,
      tstz_range,
      int4_range,
      int8_range
    ) VALUES (
      '(''2012-01-02'', ''2012-01-04'')',
      '[0.1, 0.2)',
      '[''2010-01-01 14:30'', ''2011-01-01 14:30'')',
      '[''2010-01-01 14:30:00+05'', ''2011-01-01 14:30:00-03'')',
      '(1, 10)',
      '(10, 100)'
    )
_SQL

    @connection.execute <<_SQL if @connection.supports_ranges?
    INSERT INTO postgresql_ranges (
      date_range,
      num_range,
      ts_range,
      tstz_range,
      int4_range,
      int8_range
    ) VALUES (
      '(''2012-01-02'',]',
      '[0.1,]',
      '[''2010-01-01 14:30'',]',
      '[''2010-01-01 14:30:00+05'',]',
      '(1,]',
      '(10,]'
    )
_SQL

    @connection.execute <<_SQL if @connection.supports_ranges?
    INSERT INTO postgresql_ranges (
      date_range,
      num_range,
      ts_range,
      tstz_range,
      int4_range,
      int8_range
    ) VALUES (
      '[,]',
      '[,]',
      '[,]',
      '[,]',
      '[,]',
      '[,]'
    )
_SQL

    @connection.execute <<_SQL if @connection.supports_ranges?
    INSERT INTO postgresql_ranges (
      date_range,
      num_range,
      ts_range,
      tstz_range,
      int4_range,
      int8_range
    ) VALUES (
      '(''2012-01-02'', ''2012-01-02'')',
      '(0.1, 0.1)',
      '(''2010-01-01 14:30'', ''2010-01-01 14:30'')',
      '(''2010-01-01 14:30:00+05'', ''2010-01-01 06:30:00-03'')',
      '(1, 1)',
      '(10, 10)'
    )
_SQL

    if @connection.supports_ranges?
      @first_range = PostgresqlRange.find(1)
      @second_range = PostgresqlRange.find(2)
      @third_range = PostgresqlRange.find(3)
      @fourth_range = PostgresqlRange.find(4)
      @empty_range = PostgresqlRange.find(5)
    end

    @connection.execute("INSERT INTO postgresql_tsvectors (id, text_vector) VALUES (1, ' ''text'' ''vector'' ')")

    @first_tsvector = PostgresqlTsvector.find(1)

    @connection.execute("INSERT INTO postgresql_moneys (id, wealth) VALUES (1, '567.89'::money)")
    @connection.execute("INSERT INTO postgresql_moneys (id, wealth) VALUES (2, '-567.89'::money)")
    @first_money = PostgresqlMoney.find(1)
    @second_money = PostgresqlMoney.find(2)

    @connection.execute("INSERT INTO postgresql_numbers (id, single, double) VALUES (1, 123.456, 123456.789)")
    @first_number = PostgresqlNumber.find(1)

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

  def test_data_type_of_array_types
    assert_equal :integer, @first_array.column_for_attribute(:commission_by_quarter).type
    assert_equal :text, @first_array.column_for_attribute(:nicknames).type
  end

  def test_data_type_of_range_types
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    assert_equal :daterange, @first_range.column_for_attribute(:date_range).type
    assert_equal :numrange, @first_range.column_for_attribute(:num_range).type
    assert_equal :tsrange, @first_range.column_for_attribute(:ts_range).type
    assert_equal :tstzrange, @first_range.column_for_attribute(:tstz_range).type
    assert_equal :int4range, @first_range.column_for_attribute(:int4_range).type
    assert_equal :int8range, @first_range.column_for_attribute(:int8_range).type
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

  def test_int4range_values
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    assert_equal 1...11, @first_range.int4_range
    assert_equal 2...10, @second_range.int4_range
    assert_equal 2...Float::INFINITY, @third_range.int4_range
    assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.int4_range)
    assert_equal nil, @empty_range.int4_range
  end

  def test_int8range_values
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    assert_equal 10...101, @first_range.int8_range
    assert_equal 11...100, @second_range.int8_range
    assert_equal 11...Float::INFINITY, @third_range.int8_range
    assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.int8_range)
    assert_equal nil, @empty_range.int8_range
  end

  def test_daterange_values
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    assert_equal Date.new(2012, 1, 2)...Date.new(2012, 1, 5), @first_range.date_range
    assert_equal Date.new(2012, 1, 3)...Date.new(2012, 1, 4), @second_range.date_range
    assert_equal Date.new(2012, 1, 3)...Float::INFINITY, @third_range.date_range
    assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.date_range)
    assert_equal nil, @empty_range.date_range
  end

  def test_numrange_values
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    assert_equal BigDecimal.new('0.1')..BigDecimal.new('0.2'), @first_range.num_range
    assert_equal BigDecimal.new('0.1')...BigDecimal.new('0.2'), @second_range.num_range
    assert_equal BigDecimal.new('0.1')...BigDecimal.new('Infinity'), @third_range.num_range
    assert_equal BigDecimal.new('-Infinity')...BigDecimal.new('Infinity'), @fourth_range.num_range
    assert_equal nil, @empty_range.num_range
  end

  def test_tsrange_values
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    tz = ::ActiveRecord::Base.default_timezone
    assert_equal Time.send(tz, 2010, 1, 1, 14, 30, 0)..Time.send(tz, 2011, 1, 1, 14, 30, 0), @first_range.ts_range
    assert_equal Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2011, 1, 1, 14, 30, 0), @second_range.ts_range
    assert_equal Time.send(tz, 2010, 1, 1, 14, 30, 0)...Float::INFINITY, @third_range.ts_range
    assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.ts_range)
    assert_equal nil, @empty_range.ts_range
  end

  def test_tstzrange_values
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    assert_equal Time.parse('2010-01-01 09:30:00 UTC')..Time.parse('2011-01-01 17:30:00 UTC'), @first_range.tstz_range
    assert_equal Time.parse('2010-01-01 09:30:00 UTC')...Time.parse('2011-01-01 17:30:00 UTC'), @second_range.tstz_range
    assert_equal Time.parse('2010-01-01 09:30:00 UTC')...Float::INFINITY, @third_range.tstz_range
    assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.tstz_range)
    assert_equal nil, @empty_range.tstz_range
  end

  def test_money_values
    assert_equal 567.89, @first_money.wealth
    assert_equal(-567.89, @second_money.wealth)
  end

  def test_create_tstzrange
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    tstzrange = Time.parse('2010-01-01 14:30:00 +0100')...Time.parse('2011-02-02 14:30:00 CDT')
    range = PostgresqlRange.new(:tstz_range => tstzrange)
    assert range.save
    assert range.reload
    assert_equal range.tstz_range, tstzrange
    assert_equal range.tstz_range, Time.parse('2010-01-01 13:30:00 UTC')...Time.parse('2011-02-02 19:30:00 UTC')
  end

  def test_update_tstzrange
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    new_tstzrange = Time.parse('2010-01-01 14:30:00 CDT')...Time.parse('2011-02-02 14:30:00 CET')
    assert @first_range.tstz_range = new_tstzrange
    assert @first_range.save
    assert @first_range.reload
    assert_equal @first_range.tstz_range, new_tstzrange
    assert @first_range.tstz_range = Time.parse('2010-01-01 14:30:00 +0100')...Time.parse('2010-01-01 13:30:00 +0000')
    assert @first_range.save
    assert @first_range.reload
    assert_equal @first_range.tstz_range, nil
  end

  def test_create_tsrange
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    tz = ::ActiveRecord::Base.default_timezone
    tsrange = Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2011, 2, 2, 14, 30, 0)
    range = PostgresqlRange.new(:ts_range => tsrange)
    assert range.save
    assert range.reload
    assert_equal range.ts_range, tsrange
  end

  def test_update_tsrange
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    tz = ::ActiveRecord::Base.default_timezone
    new_tsrange = Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2011, 2, 2, 14, 30, 0)
    assert @first_range.ts_range = new_tsrange
    assert @first_range.save
    assert @first_range.reload
    assert_equal @first_range.ts_range, new_tsrange
    assert @first_range.ts_range = Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2010, 1, 1, 14, 30, 0)
    assert @first_range.save
    assert @first_range.reload
    assert_equal @first_range.ts_range, nil
  end

  def test_create_numrange
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    numrange = BigDecimal.new('0.5')...BigDecimal.new('1')
    range = PostgresqlRange.new(:num_range => numrange)
    assert range.save
    assert range.reload
    assert_equal range.num_range, numrange
  end

  def test_update_numrange
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    new_numrange = BigDecimal.new('0.5')...BigDecimal.new('1')
    assert @first_range.num_range = new_numrange
    assert @first_range.save
    assert @first_range.reload
    assert_equal @first_range.num_range, new_numrange
    assert @first_range.num_range = BigDecimal.new('0.5')...BigDecimal.new('0.5')
    assert @first_range.save
    assert @first_range.reload
    assert_equal @first_range.num_range, nil
  end

  def test_create_daterange
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    daterange = Range.new(Date.new(2012, 1, 1), Date.new(2013, 1, 1), true)
    range = PostgresqlRange.new(:date_range => daterange)
    assert range.save
    assert range.reload
    assert_equal range.date_range, daterange
  end

  def test_update_daterange
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    new_daterange = Date.new(2012, 2, 3)...Date.new(2012, 2, 10)
    assert @first_range.date_range = new_daterange
    assert @first_range.save
    assert @first_range.reload
    assert_equal @first_range.date_range, new_daterange
    assert @first_range.date_range = Date.new(2012, 2, 3)...Date.new(2012, 2, 3)
    assert @first_range.save
    assert @first_range.reload
    assert_equal @first_range.date_range, nil
  end

  def test_create_int4range
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    int4range = Range.new(3, 50, true)
    range = PostgresqlRange.new(:int4_range => int4range)
    assert range.save
    assert range.reload
    assert_equal range.int4_range, int4range
  end

  def test_update_int4range
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    new_int4range = 6...10
    assert @first_range.int4_range = new_int4range
    assert @first_range.save
    assert @first_range.reload
    assert_equal @first_range.int4_range, new_int4range
    assert @first_range.int4_range = 3...3
    assert @first_range.save
    assert @first_range.reload
    assert_equal @first_range.int4_range, nil
  end

  def test_create_int8range
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    int8range = Range.new(30, 50, true)
    range = PostgresqlRange.new(:int8_range => int8range)
    assert range.save
    assert range.reload
    assert_equal range.int8_range, int8range
  end

  def test_update_int8range
    skip "PostgreSQL 9.2 required for range datatypes" unless @connection.supports_ranges?
    new_int8range = 60000...10000000
    assert @first_range.int8_range = new_int8range
    assert @first_range.save
    assert @first_range.reload
    assert_equal @first_range.int8_range, new_int8range
    assert @first_range.int8_range = 39999...39999
    assert @first_range.save
    assert @first_range.reload
    assert_equal @first_range.int8_range, nil
  end

  def test_update_tsvector
    new_text_vector = "'new' 'text' 'vector'"
    assert @first_tsvector.text_vector = new_text_vector
    assert @first_tsvector.save
    assert @first_tsvector.reload
    assert @first_tsvector.text_vector = new_text_vector
    assert @first_tsvector.save
    assert @first_tsvector.reload
    assert_equal @first_tsvector.text_vector, new_text_vector
  end

  def test_number_values
    assert_equal 123.456, @first_number.single
    assert_equal 123456.789, @first_number.double
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
    assert @first_array.commission_by_quarter = new_value
    assert @first_array.save
    assert @first_array.reload
    assert_equal @first_array.commission_by_quarter, new_value
    assert @first_array.commission_by_quarter = new_value
    assert @first_array.save
    assert @first_array.reload
    assert_equal @first_array.commission_by_quarter, new_value
  end

  def test_update_text_array
    new_value = ['robby','robert','rob','robbie']
    assert @first_array.nicknames = new_value
    assert @first_array.save
    assert @first_array.reload
    assert_equal @first_array.nicknames, new_value
    assert @first_array.nicknames = new_value
    assert @first_array.save
    assert @first_array.reload
    assert_equal @first_array.nicknames, new_value
  end

  def test_update_money
    new_value = BigDecimal.new('123.45')
    assert @first_money.wealth = new_value
    assert @first_money.save
    assert @first_money.reload
    assert_equal new_value, @first_money.wealth
  end

  def test_update_number
    new_single = 789.012
    new_double = 789012.345
    assert @first_number.single = new_single
    assert @first_number.double = new_double
    assert @first_number.save
    assert @first_number.reload
    assert_equal @first_number.single, new_single
    assert_equal @first_number.double, new_double
  end

  def test_update_time
    assert @first_time.time_interval = '2 years 3 minutes'
    assert @first_time.save
    assert @first_time.reload
    assert_equal @first_time.time_interval, '2 years 00:03:00'
  end

  def test_update_network_address
    new_inet_address = '10.1.2.3/32'
    new_cidr_address = '10.0.0.0/8'
    new_mac_address = 'bc:de:f0:12:34:56'
    assert @first_network_address.cidr_address = new_cidr_address
    assert @first_network_address.inet_address = new_inet_address
    assert @first_network_address.mac_address = new_mac_address
    assert @first_network_address.save
    assert @first_network_address.reload
    assert_equal @first_network_address.cidr_address, new_cidr_address
    assert_equal @first_network_address.inet_address, new_inet_address
    assert_equal @first_network_address.mac_address, new_mac_address
  end

  def test_update_bit_string
    new_bit_string = '11111111'
    new_bit_string_varying = '11111110'
    assert @first_bit_string.bit_string = new_bit_string
    assert @first_bit_string.bit_string_varying = new_bit_string_varying
    assert @first_bit_string.save
    assert @first_bit_string.reload
    assert_equal new_bit_string, @first_bit_string.bit_string
    assert_equal new_bit_string_varying, @first_bit_string.bit_string_varying
  end

  def test_update_oid
    new_value = 567890
    assert @first_oid.obj_id = new_value
    assert @first_oid.save
    assert @first_oid.reload
    assert_equal @first_oid.obj_id, new_value
  end

  def test_timestamp_with_zone_values_with_rails_time_zone_support
    old_tz         = ActiveRecord::Base.time_zone_aware_attributes
    old_default_tz = ActiveRecord::Base.default_timezone

    ActiveRecord::Base.time_zone_aware_attributes = true
    ActiveRecord::Base.default_timezone = :utc

    @connection.reconnect!

    @first_timestamp_with_zone = PostgresqlTimestampWithZone.find(1)
    assert_equal Time.utc(2010,1,1, 11,0,0), @first_timestamp_with_zone.time
  ensure
    ActiveRecord::Base.default_timezone = old_default_tz
    ActiveRecord::Base.time_zone_aware_attributes = old_tz
    @connection.reconnect!
  end

  def test_timestamp_with_zone_values_without_rails_time_zone_support
    old_tz         = ActiveRecord::Base.time_zone_aware_attributes
    old_default_tz = ActiveRecord::Base.default_timezone

    ActiveRecord::Base.time_zone_aware_attributes = false
    ActiveRecord::Base.default_timezone = :local

    @connection.reconnect!

    @first_timestamp_with_zone = PostgresqlTimestampWithZone.find(1)
    assert_equal Time.utc(2010,1,1, 11,0,0), @first_timestamp_with_zone.time
  ensure
    ActiveRecord::Base.default_timezone = old_default_tz
    ActiveRecord::Base.time_zone_aware_attributes = old_tz
    @connection.reconnect!
  end
end
