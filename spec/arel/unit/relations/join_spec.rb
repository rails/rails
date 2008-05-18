require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Join do
    before do
      @relation1 = Table.new(:users)
      @relation2 = Table.new(:photos)
      @predicate = @relation1[:id].eq(@relation2[:user_id])
    end
    
    describe 'hashing' do
      it 'implements hash equality' do
        Join.new("INNER JOIN", @relation1, @relation2, @predicate) \
          .should hash_the_same_as(Join.new("INNER JOIN", @relation1, @relation2, @predicate))
      end
    end
    
    describe '#engine' do
      it "delegates to a relation's engine" do
        Join.new("INNER JOIN", @relation1, @relation2, @predicate).engine.should == @relation1.engine
      end
    end
    
    describe '#attributes' do
      it 'combines the attributes of the two relations' do
        join = Join.new("INNER JOIN", @relation1, @relation2, @predicate)
        join.attributes.should ==
          (@relation1.attributes + @relation2.attributes).collect { |a| a.bind(join) }
      end
    end

    describe '#to_sql' do
      describe 'when joining with another relation' do
        it 'manufactures sql joining the two tables on the predicate' do
          Join.new("INNER JOIN", @relation1, @relation2, @predicate).to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`, `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`
            FROM `users`
              INNER JOIN `photos` ON `users`.`id` = `photos`.`user_id`
          ")
        end
      end
      
      describe 'when joining with a string' do
        it "passes the string through to the where clause" do
          Join.new("INNER JOIN asdf ON fdsa", @relation1).to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`
            FROM `users`
              INNER JOIN asdf ON fdsa
          ")
        end
      end
    end
  end
end