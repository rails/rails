require 'test_helper'

class NavigationTest < ActionDispatch::IntegrationTest
<% unless options[:skip_active_record] -%>
  fixtures :all
<% end -%>

  # Replace this with your real tests.
  test "the truth" do
    assert true
  end
end

