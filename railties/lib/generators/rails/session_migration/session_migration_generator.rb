module Rails
  module Generators
    class SessionMigrationGenerator < NamedBase #metagenerator
      argument :name, :type => :string, :default => "add_sessions_table"
      hook_for :orm, :required => true
    end
  end
end
