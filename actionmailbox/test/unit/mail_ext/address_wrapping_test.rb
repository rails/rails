# frozen_string_literal: true

require_relative '../../test_helper'

module MailExt
  class AddressWrappingTest < ActiveSupport::TestCase
    test 'wrap' do
      needing_wrapping    = Mail::Address.wrap('david@basecamp.com')
      wrapping_not_needed = Mail::Address.wrap(Mail::Address.new('david@basecamp.com'))
      assert_equal needing_wrapping.address, wrapping_not_needed.address
    end
  end
end
