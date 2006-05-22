class SessionMigrationGenerator < Rails::Generator::NamedBase
  def initialize(runtime_args, runtime_options = {})
    runtime_args << 'add_session_table' if runtime_args.empty?
    super
  end

  def manifest
    record do |m|
      m.migration_template 'migration.rb', 'db/migrate',
        :assigns => { :session_table_name => default_session_table_name }
    end
  end

  protected
    def default_session_table_name
      ActiveRecord::Base.pluralize_table_names ? 'session'.pluralize : 'session'
    end
end
