namespace :<%= file_name %> do
<% actions.each do |action| -%>
  desc "<%= action %> <%= file_name %>"
  task :<%= action %> => :environment do
  end

<% end -%>
end
