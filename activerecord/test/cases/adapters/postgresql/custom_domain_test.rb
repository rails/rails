require 'cases/helper'

class PostgreSQLCustomDomainTest < ActiveRecord::TestCase
  class CustomDomain < ActiveRecord::Base
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.execute "CREATE DOMAIN password AS TEXT"
    @connection.create_table :custom_domains do |t|
      t.column :passwd, 'password'
    end
  end

  teardown do
    if @connection
      @connection.execute 'DROP TABLE IF EXISTS custom_domains'
      @connection.execute 'DROP DOMAIN IF EXISTS password'
    end
  end

  test "custom domain types do not create errors" do
    silence_warnings do
      record = CustomDomain.create!(passwd: 'password')
      assert_equal record.id, CustomDomain.where(passwd: 'password').last.id
    end
  end
end
