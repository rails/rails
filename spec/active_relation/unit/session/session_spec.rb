require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Session do
    before do
      @relation = Table.new(:users)
      @session = Session.instance
    end
    
    describe Singleton do
      it "is a singleton" do
        Session.instance.should be_equal(Session.instance)
        lambda { Session.new }.should raise_error
      end
    end
    
    describe Session::CRUD do
      before do
        @insert = Insertion.new(@relation, @relation[:name] => 'nick')
        @update = Update.new(@relation, @relation[:name] => 'nick')
        @delete = Deletion.new(@relation)
        @select = @relation
      end
      
      describe '#create' do
        it "should execute an insertion on the connection" do
          mock(@session.connection).insert(@insert.to_sql)
          @session.create(@insert)
        end
      end
      
      describe '#read' do
        it "should execute an selection on the connection" do
          mock(@session.connection).select_all(@select.to_sql)
          @session.read(@select)
        end
      end
      
      describe '#update' do
        it "should execute an update on the connection" do
          mock(@session.connection).update(@update.to_sql)
          @session.update(@update)
        end
      end
      
      describe '#delete' do
        it "should execute a delete on the connection" do
          mock(@session.connection).delete(@delete.to_sql)
          @session.delete(@delete)
        end
      end
    end
    
    describe Session::Transactions do
      describe '#begin' do
      end
    
      describe '#end' do
      end
    end
    
    describe Session::UnitOfWork do
      describe '#flush' do
      end
      
      describe '#clear' do
      end
    end
  end
end