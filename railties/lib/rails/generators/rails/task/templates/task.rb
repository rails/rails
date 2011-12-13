namespace :<%= class_name.underscore %> do
<% actions.each do |action| -%>
  task :<%= action %> => :environment do
  end

<% end -%>
end
