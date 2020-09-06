# frozen_string_literal: true

require 'cases/helper'
require 'models/person'

module ActiveRecord
  class CustomLockingTest < ActiveRecord::TestCase
    fixtures :people

    def test_custom_lock
      if current_adapter?(:Mysql2Adapter)
        assert_match 'SHARE MODE', Person.lock('LOCK IN SHARE MODE').to_sql
        assert_sql(/LOCK IN SHARE MODE/) do
          Person.all.merge!(lock: 'LOCK IN SHARE MODE').find(1)
        end
      end
    end
  end
end
