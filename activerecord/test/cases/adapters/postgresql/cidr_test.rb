require "cases/helper"
require "ipaddr"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      class CidrTest < ActiveRecord::TestCase
        test "type casting IPAddr for database" do
          type = OID::Cidr.new
          ip = IPAddr.new("255.0.0.0/8")
          ip2 = IPAddr.new("127.0.0.1")

          assert_equal "255.0.0.0/8", type.type_cast_for_database(ip)
          assert_equal "127.0.0.1/32", type.type_cast_for_database(ip2)
        end

        test "casting does nothing with non-IPAddr objects" do
          type = OID::Cidr.new

          assert_equal "foo", type.type_cast_for_database("foo")
        end
      end
    end
  end
end
