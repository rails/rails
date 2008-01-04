require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe TableRelation, '#to_sql' do
  it "returns a simple SELECT query" do
    TableRelation.new(:users).to_sql.should == SelectBuilder.new do |s|
      select do
        column :users, :name
        column :users, :id
      end
      from :users
    end
  end
end
