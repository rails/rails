require 'spec_helper'

module Arel
  describe Table do
    before do
      @relation = Table.new(:users)
    end

    describe '#to_sql' do
      it "manufactures a simple select query" do
        sql = @relation.to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{
            SELECT `users`.`id`, `users`.`name`
            FROM `users`
          })
        end

        adapter_is :oracle do
          sql.should be_like(%Q{
            SELECT "USERS"."ID", "USERS"."NAME"
            FROM "USERS"
          })
        end

        adapter_is_not :mysql, :oracle do
          sql.should be_like(%Q{
            SELECT "users"."id", "users"."name"
            FROM "users"
          })
        end
      end
    end

    describe '#as' do
      it "manufactures a simple select query using aliases" do
        sql = @relation.as(:super_users).to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{
            SELECT `super_users`.`id`, `super_users`.`name`
            FROM `users` `super_users`
          })
        end

        adapter_is :oracle do
          sql.should be_like(%Q{
            SELECT "SUPER_USERS"."ID", "SUPER_USERS"."NAME"
            FROM "USERS" "SUPER_USERS"
          })
        end

        adapter_is_not :mysql, :oracle do
          sql.should be_like(%Q{
            SELECT "super_users"."id", "super_users"."name"
            FROM "users" "super_users"
          })
        end
      end

      it "does not apply alias if it's same as the table name" do
        sql = @relation.as(:users).to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{
            SELECT `users`.`id`, `users`.`name`
            FROM `users`
          })
        end

        adapter_is :oracle do
          sql.should be_like(%Q{
            SELECT "USERS"."ID", "USERS"."NAME"
            FROM "USERS"
          })
        end

        adapter_is_not :mysql, :oracle do
          sql.should be_like(%Q{
            SELECT "users"."id", "users"."name"
            FROM "users"
          })
        end
      end

    end

    describe '#column_for' do
      it "returns the column corresponding to the attribute" do
        @relation.column_for(@relation[:id]).should == @relation.columns.detect { |c| c.name == 'id' }
      end
    end

    describe '#attributes' do
      it 'manufactures attributes corresponding to columns in the table' do
        @relation.attributes.should == [
          Attribute.new(@relation, :id),
          Attribute.new(@relation, :name)
        ]
      end

      describe '#reset' do
        it "reloads columns from the database" do
          lambda { @relation.engine.stub!(:columns => []) }.should_not change { @relation.attributes }
          lambda { @relation.reset                        }.should     change { @relation.attributes }
        end
      end
    end

    describe 'hashing' do
      it "implements hash equality" do
        Table.new(:users).should     hash_the_same_as(Table.new(:users))
        Table.new(:users).should_not hash_the_same_as(Table.new(:photos))
      end
    end

    describe '#engine' do
      it "defaults to global engine" do
        Table.engine = engine = Sql::Engine.new
        Table.new(:users).engine.should == engine
      end

      it "can be specified" do
        Table.new(:users, engine = Sql::Engine.new).engine.should == engine
      end
    end
  end
end
