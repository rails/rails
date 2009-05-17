require File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'spec_helper')

module Arel
  describe Sql::Engine do
    before do
      @relation = Table.new(:users)
    end

    describe "CRUD" do
      describe "#create" do
        it "inserts into the relation" do
          @relation.insert @relation[:name] => "Bryan"
        end
      end

      describe "#read" do
        it "reads from the relation" do
          @relation.each do |row|
          end
        end
      end

      describe "#update" do
        it "updates the relation" do
          @relation.update @relation[:name] => "Bryan"
        end
      end

      describe "#delete" do
        it "deletes from the relation" do
          @relation.delete
        end
      end
    end
  end
end
