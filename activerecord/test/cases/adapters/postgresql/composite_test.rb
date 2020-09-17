# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

module PostgresqlCompositeBehavior
  include ConnectionHelper

  class PostgresqlComposite < ActiveRecord::Base
    self.table_name = "postgresql_composites"
  end

  def setup
    super

    @connection = ActiveRecord::Base.connection
    @connection.transaction do
      @connection.execute <<~SQL
        CREATE TYPE city    AS (country VARCHAR(90), name VARCHAR(90));
        CREATE TYPE street  AS (city city, name VARCHAR(90));
        CREATE TYPE address AS (street street, house INTEGER);
      SQL
      @connection.create_table("postgresql_composites") do |t|
        t.column :address, :address
      end
      @connection.execute <<~SQL
      INSERT INTO postgresql_composites
        VALUES (1, ROW(ROW(ROW('France', 'Paris'), 'Champs-Élysées'), 78));
      SQL
    end
  end

  def teardown
    super

    @connection.drop_table "postgresql_composites", if_exists: true
    @connection.execute "DROP TYPE IF EXISTS address"
    @connection.execute "DROP TYPE IF EXISTS street"
    @connection.execute "DROP TYPE IF EXISTS city"
    reset_connection
    PostgresqlComposite.reset_column_information
    ActiveRecord::Base.pg_composite_type_cast = :string
  end
end

# Composites are mapped to `OID::Identity` by default. The user is informed by a warning like:
#   "unknown OID 5653508: failed to recognize type of 'address'. It will be treated as String."
# To take full advantage of composite types, we suggest you register your own +OID::Type+.
# See PostgresqlCompositeWithCustomOIDTest
class PostgresqlCompositeStringTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlCompositeBehavior

  def test_column
    ensure_warning_is_issued

    column = PostgresqlComposite.columns_hash["address"]
    assert_nil column.type
    assert_equal "address", column.sql_type
    assert_not_predicate column, :array?

    type = PostgresqlComposite.type_for_attribute("address")
    assert_not_predicate type, :binary?
  end

  def test_composite_default_mapping
    ensure_warning_is_issued

    composite = PostgresqlComposite.first
    assert_equal '("(""(France,Paris)"",Champs-Élysées)",78)', composite.address

    composite.address = '("(""(France,Paris)"",Rue Basse)",78)'
    composite.save!

    # Notice that in the default implementation double quotes
    # are added around string values in nested composite types!
    # This is kept for backward-compatibility
    assert_equal '("(""(France,Paris)"",""Rue Basse"")",78)', composite.reload.address
  end

  private
  def ensure_warning_is_issued
    warning = capture(:stderr) do
      PostgresqlComposite.columns_hash
    end
    assert_match(/unknown OID \d+: failed to recognize type of 'address'\. It will be treated as String\./, warning)
  end
end

# To take full advantage of composite types, you can register your own +OID::Type+.
class PostgresqlCompositeWithCustomOIDTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlCompositeBehavior

  class AddressType < ActiveRecord::Type::Value
    def type; :address end

    def deserialize(value)
      if value =~ /\("*\("*\("*([^"]*)"*,"*([^"]*)"*\)"*,"*([^"]*)"*\)"*,"*([^"]*)"*\)/
        Address.new($1, $2, $3, $4)
      end
    end

    def cast(value)
      value
    end

    def serialize(value)
      return if value.nil?
      "(\"(\"\"(#{value.country},#{value.city})\"\",#{value.street})\",#{value.house})"
    end
  end

  Address = Struct.new(:country, :city, :street, :house)

  def setup
    super

    @connection.send(:type_map).register_type "address", AddressType.new
  end

  def test_column
    column = PostgresqlComposite.columns_hash["address"]
    assert_equal :address, column.type
    assert_equal "address", column.sql_type
    assert_not_predicate column, :array?

    type = PostgresqlComposite.type_for_attribute("address")
    assert_not_predicate type, :binary?
  end

  def test_composite_mapping
    composite = PostgresqlComposite.first

    assert_equal "France", composite.address.country
    assert_equal "Paris", composite.address.city
    assert_equal "Champs-Élysées", composite.address.street
    assert_equal "78", composite.address.house

    composite.address = Address.new("France", "Paris", "Rue Basse", 42)
    composite.save!
    composite.reload

    assert_equal "France", composite.address.country
    assert_equal "Paris", composite.address.city
    assert_equal "Rue Basse", composite.address.street
    assert_equal "42", composite.address.house
  end
end

# With `pg_composite_type_cast = :hash` setting composite types
# are mapped to `OID::Composite` <de>serializing
# values from PostgreSQL columns into Ruby hashes.
class PostgresqlCompositeHashTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlCompositeBehavior

  def setup
    super
    ActiveRecord::Base.pg_composite_type_cast = :hash
  end

  def test_composite_mapping_to_hash
    composite = PostgresqlComposite.first

    # The address is deserialized from tuple into Hash
    assert_equal(
      '("(""(France,Paris)"",Champs-Élysées)",78)',
      composite.address_before_type_cast,
    )
    assert_equal(
      { street: { city: { country: "France", name: "Paris" }, name: "Champs-Élysées" }, house: 78 },
      composite.address,
    )

    # It can be changed in memory as a hash
    composite.address[:street][:name] = "Rue Basse"
    assert_equal(
      { street: { city: { country: "France", name: "Paris" }, name: "Rue Basse" }, house: 78 },
      composite.address,
    )

    # It casts any value responding to #to_h
    composite.address = Struct.new(:street, :house)[
      Struct.new(:city, :name)[
        Struct.new(:country, :name)["Nederland", "Amsterdam"],
        "Damrak",
      ],
      42,
    ]
    assert_equal(
      { street: { city: { country: "Nederland", name: "Amsterdam" }, name: "Damrak" }, house: 42 },
      composite.address,
    )

    # Or it can be set as a good old tuple
    composite.address = "(((Россия,Москва),Покровка),13)"
    assert_equal(
      { street: { city: { country: "Россия", name: "Москва" }, name: "Покровка" }, house: 13 },
      composite.address,
    )

    # The dirty methods work as expected
    assert_equal(true, composite.address_changed?)
    assert_equal(
      [
        { "street" => { "city" => { "country" => "France", "name" => "Paris" }, "name" => "Champs-Élysées" }, "house" => 78 },
        { "street" => { "city" => { "country" => "Россия", "name" => "Москва" }, "name" => "Покровка" }, "house" => 13 },
      ],
      composite.changes["address"],
    )

    # Dirty methods work for previous_changes as well
    composite.save!
    assert_equal(
      [
        { "street" => { "city" => { "country" => "France", "name" => "Paris" }, "name" => "Champs-Élysées" }, "house" => 78 },
        { "street" => { "city" => { "country" => "Россия", "name" => "Москва" }, "name" => "Покровка" }, "house" => 13 },
      ],
      composite.previous_changes["address"],
    )

    # Updated data are saved properly and deserialized back again
    assert_equal(
      '("(""(Россия,Москва)"",Покровка)",13)',
      composite.reload.address_before_type_cast
    )
    assert_equal(
      { street: { city: { country: "Россия", name: "Москва" }, name: "Покровка" }, house: 13 },
      composite.address,
    )

    # Ensure that all types are registered, and there's no fallback to the Type::Value any more.
    ensure_warning_is_not_issued
  end

  private
    def ensure_warning_is_not_issued
      warning = capture(:stderr) do
        PostgresqlComposite.columns_hash
      end

      assert_no_match(/unknown OID \d+: failed to recognize type/, warning)
    end
end

# You can add custom serializer via interface of
# `ActiveRecord::AttributeMethods::Serialization`.
# With `pg_composite_type_cast = :hash` the serialization
# should be provided from/into hash.
class PostgresqlCompositeHashWithCustomSerializerTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlCompositeBehavior

  def setup
    super
    ActiveRecord::Base.pg_composite_type_cast = :hash
  end

  module AddressSerializer
    extend self

    STRUCT = Struct.new(:country, :city, :street, :house)

    def load(value)
      return unless value.is_a?(Hash)

      country = value.dig(:street, :city, :country)
      city = value.dig(:street, :city, :name)
      street = value.dig(:street, :name)
      house = value.dig(:house)
      STRUCT[country, city, street, house]
    end

    def dump(value)
      case value
      when NilClass then nil
      when Hash then value
      else
        {
          house: value.house,
          street: {
            name: value.street,
            city: { country: value.country, name: value.city },
          },
        }
      end
    end
  end

  class PostgresqlComposite < ActiveRecord::Base
    serialize :address, AddressSerializer
  end

  def test_composite_mapping_to_hash
    composite = PostgresqlComposite.first

    assert_equal "France", composite.address.country
    assert_equal "Paris", composite.address.city
    assert_equal "Champs-Élysées", composite.address.street
    assert_equal 78, composite.address.house

    composite.address = AddressSerializer::STRUCT["France", "Paris", "Rue Basse", 42]
    composite.save!
    composite.reload

    assert_equal "France", composite.address.country
    assert_equal "Paris", composite.address.city
    assert_equal "Rue Basse", composite.address.street
    assert_equal 42, composite.address.house
  end
end
