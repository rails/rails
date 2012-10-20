class <%= file_name.camelize %> < Thor
  
<% actions.each do |action| -%>
  desc "<%= action %>", "TODO"
  def <%= action %>
    require './config/environment'
  end

<% end -%>
end
