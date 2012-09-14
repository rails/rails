class Emp < ActiveRecord::Base
  if connection.class.to_s == "ActiveRecord::ConnectionAdapters::OracleAdapter"
    set_table_name "#{connection.current_user.downcase}.emps"
  end
  belongs_to :dept, :select => "id, name nombre"
end