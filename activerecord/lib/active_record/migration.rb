module ActiveRecord
  class IrreversibleMigration < ActiveRecordError#:nodoc:
  end
  
  class Migration #:nodoc:
    class << self
      def up() end
      def down() end

      private
        def method_missing(method, *arguments, &block)
          ActiveRecord::Base.connection.send(method, *arguments, &block)
        end
    end
  end

  class Migrator#:nodoc:
    class << self
      def up(migrations_path, target_version = nil)
        new(:up, migrations_path, target_version).migrate
      end
      
      def down(migrations_path, target_version = nil)
        new(:down, migrations_path, target_version).migrate
      end
      
      def current_version
        Base.connection.select_one("SELECT version FROM schema_info")["version"].to_i
      end
    end
    
    def initialize(direction, migrations_path, target_version = nil)
      @direction, @migrations_path, @target_version = direction, migrations_path, target_version
      Base.connection.initialize_schema_information
    end

    def current_version
      self.class.current_version
    end

    def migrate
      migration_classes do |version, migration_class|
        Base.logger.info("Reached target version: #{@target_version}") and break if reached_target_version?(version)
        next if irrelevant_migration?(version)

        Base.logger.info "Migrating to #{migration_class} (#{version})"
        migration_class.send(@direction)
        set_schema_version(version)
      end
    end

    private
      def migration_classes
        for migration_file in migration_files
          load(migration_file)
          version, name = migration_version_and_name(migration_file)
          yield version, migration_class(name)
        end
      end
    
      def migration_files
        files = Dir["#{@migrations_path}/[0-9]*_*.rb"].sort
        down? ? files.reverse : files
      end
      
      def migration_class(migration_name)
        migration_name.camelize.constantize
      end
    
      def migration_version_and_name(migration_file)
        return *migration_file.scan(/([0-9]+)_([_a-z0-9]*).rb/).first
      end
      
      def set_schema_version(version)
        Base.connection.update("UPDATE schema_info SET version = #{down? ? version.to_i - 1 : version.to_i}")
      end
      
      def up?
        @direction == :up
      end
      
      def down?
        @direction == :down
      end
      
      def reached_target_version?(version)
        (up? && version.to_i - 1 == @target_version) || (down? && version.to_i == @target_version)
      end
      
      def irrelevant_migration?(version)
        (up? && version.to_i <= current_version) || (down? && version.to_i > current_version)
      end
  end
end
