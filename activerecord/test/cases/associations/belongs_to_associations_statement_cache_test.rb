require 'cases/helper'

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

        execute "ALTER TABLE dities
                   ALTER COLUMN id DROP DEFAULT,
                   ALTER COLUMN id SET DATA TYPE UUID USING (uuid(lpad(replace(text(id),'-',''), 32, '0'))),
                   ALTER COLUMN id SET DEFAULT uuid_generate_v4()"

        execute "ALTER TABLE dtudents
                   ALTER COLUMN dity_id SET DATA TYPE UUID USING (uuid(lpad(replace(text(dity_id),'-',''), 32, '0')))"
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
    dity_name_post= dtudent_post.dity.name

    assert (dity_name_pre == dity_name_post)
  end

end
