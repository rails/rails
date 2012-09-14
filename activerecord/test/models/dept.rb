class Dept < ActiveRecord::Base
  if connection.class.to_s == "ActiveRecord::ConnectionAdapters::OracleAdapter"
    set_table_name "#{connection.current_user.downcase}.depts"
  end
end
