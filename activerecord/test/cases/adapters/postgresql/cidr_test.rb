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

        test "changed? with nil values" do
          type = OID::Cidr.new

          assert_not type.changed?(nil, nil, "")
          assert type.changed?("192.168.0.0/24", nil, "")
          assert type.changed?(nil, "192.168.0.0/24", "")
          assert type.changed?("192.168.0.0/24", "192.168.0.0/25", "")
          assert type.changed?(IPAddr.new("192.168.0.0/24"), nil, "")
          assert type.changed?(nil, IPAddr.new("192.168.0.0/24"), "")
          assert type.changed?(IPAddr.new("192.168.0.0/24"), IPAddr.new("192.168.0.0/25"), "")

          assert type.changed?(IPAddr.new("0.0.0.0"), nil, "")
          assert type.changed?(nil, IPAddr.new("0.0.0.0"), "")
          assert type.changed?(IPAddr.new("::"), nil, "")
          assert type.changed?(nil, IPAddr.new("::"), "")
        end
      end
    end
  end
end
