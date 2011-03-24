require 'test_helper'

<% module_namespacing do -%>
class <%= class_name %>Test < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "the truth" do
    assert true
  end
end
<% end -%>
