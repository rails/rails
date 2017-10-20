# frozen_string_literal: true

require "cases/helper"
require "ipaddr"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      class CidrTest < ActiveRecord::PostgreSQLTestCase
        test "type casting IPAddr for database" do
          type = OID::Cidr.new
          ip = IPAddr.new("255.0.0.0/8")
          ip2 = IPAddr.new("127.0.0.1")

          assert_equal "255.0.0.0/8", type.serialize(ip)
          assert_equal "127.0.0.1/32", type.serialize(ip2)
        end

        test "casting does nothing with non-IPAddr objects" do
          type = OID::Cidr.new

          assert_equal "foo", type.serialize("foo")
        end
      end
    end
  end
end
