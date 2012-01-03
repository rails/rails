# -*- encoding : utf-8 -*-
require 'test_helper'

class NavigationTest < ActionDispatch::IntegrationTest
<% unless options[:skip_active_record] -%>
  fixtures :all
<% end -%>

  # test "the truth" do
  #   assert true
  # end
end

