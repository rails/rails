module Rails
  module Generators
    class SessionMigrationGenerator < NamedBase
      argument :name, :type => :string, :default => "add_session_table"
      hook_for :orm
    end
  end
end
