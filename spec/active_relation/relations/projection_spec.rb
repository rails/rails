require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Projection do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end
    
    describe '#attributes' do
      before do
        @projection = Projection.new(@relation, @attribute)
      end
      
      it "manufactures attributes associated with the projection relation" do
        @projection.attributes.should == [@attribute].collect { |a| a.bind(@projection) }
      end
    end
    
    describe '==' do
      before do
        @another_relation = Table.new(:photos)
        @another_attribute = @relation[:name]
      end
      
      it "obtains if the relations and attributes are identical" do
        Projection.new(@relation, @attribute).should == Projection.new(@relation, @attribute)
        Projection.new(@relation, @attribute).should_not == Projection.new(@another_relation, @attribute)
        Projection.new(@relation, @attribute).should_not == Projection.new(@relation, @another_attribute)
      end
    end
  
    describe '#qualify' do
      it "distributes over the relation and attributes" do
        Projection.new(@relation, @attribute).qualify. \
          should == Projection.new(@relation.qualify, @attribute.qualify)
      end
    end
  
    describe '#to_sql' do
      it "manufactures sql with a limited select clause" do
        Projection.new(@relation, @attribute).to_sql.should be_like("""
          SELECT `users`.`id`
          FROM `users`
        """)
      end
      
      it "manufactures sql with scalar selects" do
        Projection.new(@relation, Projection.new(@relation, @relation[:name])).to_sql.should be_like("""
          SELECT (SELECT `users`.`name` FROM `users`) FROM `users`
        """)
      end
    end
  end
end