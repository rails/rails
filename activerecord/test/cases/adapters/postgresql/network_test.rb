# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class PostgresqlNetworkTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper
  class PostgresqlNetworkAddress < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table("postgresql_network_addresses", force: true) do |t|
      t.inet "inet_address", default: "192.168.1.1"
      t.cidr "cidr_address", default: "192.168.1.0/24"
      t.macaddr "mac_address", default: "ff:ff:ff:ff:ff:ff"
    end
  end

  teardown do
    @connection.drop_table "postgresql_network_addresses", if_exists: true
  end

  def test_cidr_column
    column = PostgresqlNetworkAddress.columns_hash["cidr_address"]
    assert_equal :cidr, column.type
    assert_equal "cidr", column.sql_type
    assert_not column.array?

    type = PostgresqlNetworkAddress.type_for_attribute("cidr_address")
    assert_not type.binary?
  end

  def test_inet_column
    column = PostgresqlNetworkAddress.columns_hash["inet_address"]
    assert_equal :inet, column.type
    assert_equal "inet", column.sql_type
    assert_not column.array?

    type = PostgresqlNetworkAddress.type_for_attribute("inet_address")
    assert_not type.binary?
  end

  def test_macaddr_column
    column = PostgresqlNetworkAddress.columns_hash["mac_address"]
    assert_equal :macaddr, column.type
    assert_equal "macaddr", column.sql_type
    assert_not column.array?

    type = PostgresqlNetworkAddress.type_for_attribute("mac_address")
    assert_not type.binary?
  end

  def test_network_types
    PostgresqlNetworkAddress.create(cidr_address: "192.168.0.0/24",
                                    inet_address: "172.16.1.254/32",
                                    mac_address: "01:23:45:67:89:0a")

    address = PostgresqlNetworkAddress.first
    assert_equal IPAddr.new("192.168.0.0/24"), address.cidr_address
    assert_equal IPAddr.new("172.16.1.254"), address.inet_address
    assert_equal "01:23:45:67:89:0a", address.mac_address

    address.cidr_address = "10.1.2.3/32"
    address.inet_address = "10.0.0.0/8"
    address.mac_address = "bc:de:f0:12:34:56"

    address.save!
    assert address.reload
    assert_equal IPAddr.new("10.1.2.3/32"), address.cidr_address
    assert_equal IPAddr.new("10.0.0.0/8"), address.inet_address
    assert_equal "bc:de:f0:12:34:56", address.mac_address
  end

  def test_invalid_network_address
    invalid_address = PostgresqlNetworkAddress.new(cidr_address: "invalid addr",
                                                   inet_address: "invalid addr")
    assert_nil invalid_address.cidr_address
    assert_nil invalid_address.inet_address
    assert_equal "invalid addr", invalid_address.cidr_address_before_type_cast
    assert_equal "invalid addr", invalid_address.inet_address_before_type_cast
    assert invalid_address.save

    invalid_address.reload
    assert_nil invalid_address.cidr_address
    assert_nil invalid_address.inet_address
    assert_nil invalid_address.cidr_address_before_type_cast
    assert_nil invalid_address.inet_address_before_type_cast
  end

  def test_schema_dump_with_shorthand
    output = dump_table_schema("postgresql_network_addresses")
    assert_match %r{t\.inet\s+"inet_address",\s+default: "192\.168\.1\.1"}, output
    assert_match %r{t\.cidr\s+"cidr_address",\s+default: "192\.168\.1\.0/24"}, output
    assert_match %r{t\.macaddr\s+"mac_address",\s+default: "ff:ff:ff:ff:ff:ff"}, output
  end
end
