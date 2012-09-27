ActiveSupport::Deprecation.silence do
  require 'active_record/test_case'
end

ActiveRecord::TestCase.class_eval do
  def sqlite3? connection
    connection.class.name.split('::').last == "SQLite3Adapter"
  end
end
