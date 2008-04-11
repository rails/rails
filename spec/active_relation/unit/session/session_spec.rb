require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Session do
    before do
      @relation = Table.new(:users)
      @session = Session.new
    end
    
    describe '::start' do
      describe '::instance' do
        it "it is a singleton within the started session" do
          Session.start do
            Session.new.should == Session.new
          end
        end

        it "is a singleton across nested sessions" do
          Session.start do
            outside = Session.new
            Session.start do
              Session.new.should == outside
            end
          end
        end
      
        it "manufactures new sessions outside of the started session" do
          Session.new.should_not == Session.new
        end
      end
    end
    
    describe Session::CRUD do
      before do
        @insert = Insertion.new(@relation, @relation[:name] => 'nick')
        @update = Update.new(@relation, @relation[:name] => 'nick')
        @delete = Deletion.new(@relation)
        @read = @relation
      end
      
      describe '#create' do
        it "executes an insertion on the connection" do
          mock(@insert).call(@insert.engine.connection)
          @session.create(@insert)
        end
      end
      
      describe '#read' do
        it "executes an selection on the connection" do
          mock(@read).call(@read.engine.connection)
          @session.read(@read)
        end
        
        it "is memoized" do
          mock(@read).call(@read.engine.connection).once
          @session.read(@read)
          @session.read(@read)
        end
      end
      
      describe '#update' do
        it "executes an update on the connection" do
          mock(@update).call(@update.engine.connection)
          @session.update(@update)
        end
      end
      
      describe '#delete' do
        it "executes a delete on the connection" do
          mock(@delete).call(@delete.engine.connection)
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