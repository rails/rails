# -*- encoding : utf-8 -*-
<% if mountable? -%>
<%= camelized %>::Engine.routes.draw do
<% else -%>
Rails.application.routes.draw do
<% end -%>
end
