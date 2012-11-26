require "cases/helper"
require "models/invoice"
require "models/line_item"

class CacheKeyTest < ActiveRecord::TestCase
  def setup
    @invoice = Invoice.create
    LineItem.create(invoice: @invoice)
    @invoice.reload
  end

  def test_cache_key_changes_when_child_touched
    key = @invoice.cache_key
    @invoice.reload
    @invoice.line_items[0].touch
    assert_not_equal key, @invoice.cache_key
  end
end
