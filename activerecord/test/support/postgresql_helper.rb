module PostgresqlHelper
  # Make sure to drop all cached query plans to prevent invalid reference errors like:
  #  cache lookup failed for type XYZ
  def reset_pg_session
    original_connection = ActiveRecord::Base.remove_connection
    ActiveRecord::Base.establish_connection(original_connection)
  end
end
