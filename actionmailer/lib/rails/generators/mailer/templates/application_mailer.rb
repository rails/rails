# frozen_string_literal: true

<% module_namespacing do -%>
class ApplicationMailer < ActionMailer::Base
  default from: 'from@example.com'
  layout 'mailer'
end
<% end %>
