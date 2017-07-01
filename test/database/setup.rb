require "active_file/migration"

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveFile::CreateBlobs.migrate(:up)
