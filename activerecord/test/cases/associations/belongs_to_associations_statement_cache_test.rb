# The reset_column_information does not clear some cached database statements. This affects
# cases where the underlying column types changes. In this case ActiveRecord throws an
# exception complaining StatementInvalid.
#
# This testcase uses its own models and migrations as it updates the underlying column types
# from integer to uuid.
#
# Names of models and tables are quirky student -> dtudent and city -> dity
# to avoid conflict with any other test cases or models
#
# The bug was discovered during testing of gem webdack-uuid_migration
# That gem allows in place upgrading of Postgres databses to use UUIDs
# This bug most likely had appeared in some version of 4.x.x
#
# For any information on this test case, please contact at deepak@kreatio.com
#


require 'cases/helper'

require 'webdack/uuid_migration/helpers'

class Dity < ActiveRecord::Base
  has_many :dtudents
end

class Dtudent < ActiveRecord::Base
  belongs_to :dity

  # Using the below association avoids the bug
  # belongs_to :dity, -> { where('true') }
end

class BelongsToAssociationsStatementCacheTestMigration < ActiveRecord::Migration
  def change
    create_table "dities" do |t|
      t.string "name"
    end

    create_table "dtudents" do |t|
      t.string "name"
      t.integer "dity_id"

      t.index "dity_id"
    end
  end
end

class MigrateAllOneGo < ActiveRecord::Migration
  def change
    reversible do |dir|
      dir.up do
        enable_extension 'uuid-ossp'

        primary_key_to_uuid :dities

        primary_key_to_uuid :dtudents
        columns_to_uuid :dtudents, :dity_id
      end

      dir.down do
        raise ActiveRecord::IrreversibleMigration
      end
    end
  end
end

class BelongsToAssociationsStatementCacheTest < ActiveRecord::TestCase

  test 'belongs_to does not aggressively caches database prepared statements' do
    skip('Only for Postgres') unless current_adapter?(:PostgreSQLAdapter)

    silence_stream(STDOUT) do
      BelongsToAssociationsStatementCacheTestMigration.migrate(:up)
    end

    Dity.create(:name => "Dity 1")
    Dtudent.create(
        :name => "Dtudent 1",
        :dity => Dity.where(:name => "Dity 1").first
    )

    dtudent_pre= Dtudent.first
    dity_name_pre= dtudent_pre.dity.name

    silence_stream(STDOUT) do
      MigrateAllOneGo.migrate(:up)
    end

    [Dity, Dtudent].each { |klass| klass.reset_column_information }

    dtudent_post= Dtudent.first
    dtudent_post.dity
    dity_name_post= dtudent_post.dity.name

    assert (dity_name_pre == dity_name_post)
  end

end
