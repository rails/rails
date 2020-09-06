# frozen_string_literal: true

require_relative '../../test_helper'

module MailExt
  class AddressEqualityTest < ActiveSupport::TestCase
    test 'two addresses with the same address are equal' do
      assert_equal Mail::Address.new('david@basecamp.com'), Mail::Address.new('david@basecamp.com')
    end
  end
end
