require 'abstract_unit'

class PostgresqlArray < ActiveRecord::Base
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

class PostgresqlDataTypeTest < Test::Unit::TestCase
  self.use_transactional_fixtures = false

  def setup
    @connection = ActiveRecord::Base.connection

    @connection.execute("INSERT INTO postgresql_arrays (commission_by_quarter, nicknames) VALUES ( '{35000,21000,18000,17000}', '{foo,bar,baz}' )")
    @first_array = PostgresqlArray.find(1)

    @connection.execute("INSERT INTO postgresql_moneys (wealth) VALUES ('$567.89')")
    @connection.execute("INSERT INTO postgresql_moneys (wealth) VALUES ('-$567.89')")
    @first_money = PostgresqlMoney.find(1)
    @second_money = PostgresqlMoney.find(2)

    @connection.execute("INSERT INTO postgresql_numbers (single, double) VALUES (123.456, 123456.789)")
    @first_number = PostgresqlNumber.find(1)

    @connection.execute("INSERT INTO postgresql_times (time_interval) VALUES ('1 year 2 days ago')")
    @first_time = PostgresqlTime.find(1)

    @connection.execute("INSERT INTO postgresql_network_addresses (cidr_address, inet_address, mac_address) VALUES('192.168.0/24', '172.16.1.254/32', '01:23:45:67:89:0a')")
    @first_network_address = PostgresqlNetworkAddress.find(1)
    
    @connection.execute("INSERT INTO postgresql_bit_strings (bit_string, bit_string_varying) VALUES (B'00010101', X'15')")
    @first_bit_string = PostgresqlBitString.find(1)
    
    @connection.execute("INSERT INTO postgresql_oids (obj_id) VALUES (1234)")
    @first_oid = PostgresqlOid.find(1)
  end

  def test_data_type_of_array_types
    assert_equal :string, @first_array.column_for_attribute(:commission_by_quarter).type
    assert_equal :string, @first_array.column_for_attribute(:nicknames).type
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
  end

  def test_data_type_of_network_address_types
    assert_equal :string, @first_network_address.column_for_attribute(:cidr_address).type
    assert_equal :string, @first_network_address.column_for_attribute(:inet_address).type
    assert_equal :string, @first_network_address.column_for_attribute(:mac_address).type
  end

  def test_data_type_of_bit_string_types
    assert_equal :string, @first_bit_string.column_for_attribute(:bit_string).type
    assert_equal :string, @first_bit_string.column_for_attribute(:bit_string_varying).type
  end

  def test_data_type_of_oid_types
    assert_equal :integer, @first_oid.column_for_attribute(:obj_id).type
  end

  def test_array_values
   assert_equal '{35000,21000,18000,17000}', @first_array.commission_by_quarter
   assert_equal '{foo,bar,baz}', @first_array.nicknames
  end

  def test_money_values
    assert_equal 567.89, @first_money.wealth
    assert_equal -567.89, @second_money.wealth
  end

  def test_number_values
    assert_equal 123.456, @first_number.single
    assert_equal 123456.789, @first_number.double
  end

  def test_time_values
    assert_equal '-1 years -2 days', @first_time.time_interval
  end

  def test_network_address_values
    assert_equal '192.168.0.0/24', @first_network_address.cidr_address
    assert_equal '172.16.1.254', @first_network_address.inet_address
    assert_equal '01:23:45:67:89:0a', @first_network_address.mac_address
  end

  def test_bit_string_values
    assert_equal '00010101', @first_bit_string.bit_string
    assert_equal '00010101', @first_bit_string.bit_string_varying
  end

  def test_oid_values
    assert_equal 1234, @first_oid.obj_id
  end

  def test_update_integer_array
    new_value = '{32800,95000,29350,17000}'
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
    new_value = '{robby,robert,rob,robbie}'
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
    new_value = 123.45
    assert @first_money.wealth = new_value
    assert @first_money.save
    assert @first_money.reload
    assert_equal @first_money.wealth, new_value
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
    new_cidr_address = '10.1.2.3/32'
    new_inet_address = '10.0.0.0/8'
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
    new_bit_string_varying = 'FF'
    assert @first_bit_string.bit_string = new_bit_string
    assert @first_bit_string.bit_string_varying = new_bit_string_varying
    assert @first_bit_string.save
    assert @first_bit_string.reload
    assert_equal @first_bit_string.bit_string, new_bit_string
    assert_equal @first_bit_string.bit_string, @first_bit_string.bit_string_varying
  end

  def test_update_oid
    new_value = 567890
    assert @first_oid.obj_id = new_value
    assert @first_oid.save
    assert @first_oid.reload
    assert_equal @first_oid.obj_id, new_value
  end
end
