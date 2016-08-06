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
      @connection.execute <<-SQL
         CREATE TYPE full_address AS
         (
             city VARCHAR(90),
             street VARCHAR(90)
         );
        SQL
      @connection.create_table("postgresql_composites") do |t|
        t.column :address, :full_address
      end
    end
  end

  def teardown
    super

    @connection.drop_table "postgresql_composites", if_exists: true
    @connection.execute "DROP TYPE IF EXISTS full_address"
    reset_connection
    PostgresqlComposite.reset_column_information
  end
end

# Composites are mapped to `OID::Identity` by default. The user is informed by a warning like:
#   "unknown OID 5653508: failed to recognize type of 'address'. It will be treated as String."
# To take full advantage of composite types, we suggest you register your own +OID::Type+.
# See PostgresqlCompositeWithCustomOIDTest
class PostgresqlCompositeTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlCompositeBehavior

  def test_column
    ensure_warning_is_issued

    column = PostgresqlComposite.columns_hash["address"]
    assert_nil column.type
    assert_equal "full_address", column.sql_type
    assert_not column.array?

    type = PostgresqlComposite.type_for_attribute("address")
    assert_not type.binary?
  end

  def test_composite_mapping
    ensure_warning_is_issued

    @connection.execute "INSERT INTO postgresql_composites VALUES (1, ROW('Paris', 'Champs-Élysées'));"
    composite = PostgresqlComposite.first
    assert_equal "(Paris,Champs-Élysées)", composite.address

    composite.address = "(Paris,Rue Basse)"
    composite.save!

    assert_equal '(Paris,"Rue Basse")', composite.reload.address
  end

  private
  def ensure_warning_is_issued
    warning = capture(:stderr) do
      PostgresqlComposite.columns_hash
    end
    assert_match(/unknown OID \d+: failed to recognize type of 'address'\. It will be treated as String\./, warning)
  end
end

class PostgresqlCompositeWithCustomOIDTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlCompositeBehavior

  class FullAddressType < ActiveRecord::Type::Value
    def type; :full_address end

    def deserialize(value)
      if value =~ /\("?([^",]*)"?,"?([^",]*)"?\)/
        FullAddress.new($1, $2)
      end
    end

    def cast(value)
      value
    end

    def serialize(value)
      return if value.nil?
      "(#{value.city},#{value.street})"
    end
  end

  FullAddress = Struct.new(:city, :street)

  def setup
    super

    @connection.type_map.register_type "full_address", FullAddressType.new
  end

  def test_column
    column = PostgresqlComposite.columns_hash["address"]
    assert_equal :full_address, column.type
    assert_equal "full_address", column.sql_type
    assert_not column.array?

    type = PostgresqlComposite.type_for_attribute("address")
    assert_not type.binary?
  end

  def test_composite_mapping
    @connection.execute "INSERT INTO postgresql_composites VALUES (1, ROW('Paris', 'Champs-Élysées'));"
    composite = PostgresqlComposite.first
    assert_equal "Paris", composite.address.city
    assert_equal "Champs-Élysées", composite.address.street

    composite.address = FullAddress.new("Paris", "Rue Basse")
    composite.save!

    assert_equal "Paris", composite.reload.address.city
    assert_equal "Rue Basse", composite.reload.address.street
  end
end
