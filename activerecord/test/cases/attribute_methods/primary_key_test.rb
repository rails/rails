require 'cases/helper'
require 'models/subscriber'

module ActiveRecord
  module AttributeMethods
    module PrimaryKey
      class PrimaryKeyTest < ActiveModel::TestCase
        test "to_key implementation for new ActiveRecord::Base inherited class object" do
          assert_equal ['Aditya'], Subscriber.new(nick: 'Aditya').to_key
        end

        test "to_key implementation for ActiveRecord::Base persisted class object" do
          assert_equal ['Aditya'], Subscriber.create(nick: 'Aditya').to_key
        end
      end
    end
  end
end