require "cases/helper"
require "ipaddr"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      class InetTest < ActiveRecord::PostgreSQLTestCase
        test "type casting IPAddr for database" do
          type = OID::Inet.new
          ip = IPAddr.new("255.0.0.0/8")
          ip2 = IPAddr.new("127.0.0.1/32")
          ip3 = IPAddr.new("2001:db8::/64")
          ip4 = IPAddr.new("2001:db8::1/128")

          assert_equal "255.0.0.0/8", type.serialize(ip)
          assert_equal "127.0.0.1", type.serialize(ip2)
          assert_equal "2001:db8::/64", type.serialize(ip3)
          assert_equal "2001:db8::1", type.serialize(ip4)
        end
      end
    end
  end
end
