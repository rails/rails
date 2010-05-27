share_examples_for 'A Relation' do

  before :all do
    # The two needed instance variables need to be set in a
    # before :all callback.
    #   @relation is the relation being tested here.
    #   @expected is an array of the elements that are expected to be in
    #     the relation.
    %w[ @relation @expected ].each do |ivar|
      raise "#{ivar} needs to be defined" unless instance_variable_get(ivar)
    end

    # There needs to be enough items to be able to run all the tests
    raise "@expected needs to have at least 6 items" unless @expected.length >= 6
  end

  before :each do
    @expected = @expected.dup
  end

  describe "#each" do
    it "iterates over the rows in any order" do
      @relation.should have_rows(@expected)
    end
  end

  describe "#where" do
    before :all do
      @expected = @expected.sort_by { |r| r[@relation[:age]] }
      @pivot = @expected[@expected.length / 2]
    end

    it "finds rows with an equal to predicate" do
      expected = @expected.select { |r| r[@relation[:age]] == @pivot[@relation[:age]] }
      @relation.where(@relation[:age].eq(@pivot[@relation[:age]])).should have_rows(expected)
    end

    it "finds rows with an equal to complement predicate" do
      expected = @expected.select { |r| r[@relation[:age]] != @pivot[@relation[:age]] }
      @relation.where(@relation[:age].eq(@pivot[@relation[:age]]).complement).should have_rows(expected)
    end

    it "finds rows with a not eq predicate" do
      expected = @expected.select { |r| r[@relation[:age]] != @pivot[@relation[:age]] }
      @relation.where(@relation[:age].not_eq(@pivot[@relation[:age]])).should have_rows(expected)
    end

    it "finds rows with an not eq complement predicate" do
      expected = @expected.select { |r| r[@relation[:age]] == @pivot[@relation[:age]] }
      @relation.where(@relation[:age].not_eq(@pivot[@relation[:age]]).complement).should have_rows(expected)
    end

    it "finds rows with a less than predicate" do
      expected = @expected.select { |r| r[@relation[:age]] < @pivot[@relation[:age]] }
      @relation.where(@relation[:age].lt(@pivot[@relation[:age]])).should have_rows(expected)
    end

    it "finds rows with a less than complement predicate" do
      expected = @expected.select { |r| r[@relation[:age]] >= @pivot[@relation[:age]] }
      @relation.where(@relation[:age].lt(@pivot[@relation[:age]]).complement).should have_rows(expected)
    end

    it "finds rows with a less than or equal to predicate" do
      expected = @expected.select { |r| r[@relation[:age]] <= @pivot[@relation[:age]] }
      @relation.where(@relation[:age].lteq(@pivot[@relation[:age]])).should have_rows(expected)
    end

    it "finds rows with a less than or equal to complement predicate" do
      expected = @expected.select { |r| r[@relation[:age]] > @pivot[@relation[:age]] }
      @relation.where(@relation[:age].lteq(@pivot[@relation[:age]]).complement).should have_rows(expected)
    end

    it "finds rows with a greater than predicate" do
      expected = @expected.select { |r| r[@relation[:age]] > @pivot[@relation[:age]] }
      @relation.where(@relation[:age].gt(@pivot[@relation[:age]])).should have_rows(expected)
    end

    it "finds rows with a greater than complement predicate" do
      expected = @expected.select { |r| r[@relation[:age]] <= @pivot[@relation[:age]] }
      @relation.where(@relation[:age].gt(@pivot[@relation[:age]]).complement).should have_rows(expected)
    end

    it "finds rows with a greater than or equal to predicate" do
      expected = @expected.select { |r| r[@relation[:age]] >= @pivot[@relation[:age]] }
      @relation.where(@relation[:age].gteq(@pivot[@relation[:age]])).should have_rows(expected)
    end

    it "finds rows with a greater than or equal to complement predicate" do
      expected = @expected.select { |r| r[@relation[:age]] < @pivot[@relation[:age]] }
      @relation.where(@relation[:age].gteq(@pivot[@relation[:age]]).complement).should have_rows(expected)
    end

    it "finds rows with a matches predicate" do
      expected = @expected.select { |r| r[@relation[:name]] =~ /#{@pivot[@relation[:name]]}/ }
      @relation.where(@relation[:name].matches(/#{@pivot[@relation[:name]]}/)).should have_rows(expected)
    end

    it "finds rows with a matches complement predicate" do
      expected = @expected.select { |r| r[@relation[:name]] !~ /#{@pivot[@relation[:name]]}/ }
      @relation.where(@relation[:name].matches(/#{@pivot[@relation[:name]]}/).complement).should have_rows(expected)
    end

    it "finds rows with a not matches predicate" do
      expected = @expected.select { |r| r[@relation[:name]] !~ /#{@pivot[@relation[:name]]}/ }
      @relation.where(@relation[:name].not_matches(/#{@pivot[@relation[:name]]}/)).should have_rows(expected)
    end

    it "finds rows with a not matches complement predicate" do
      expected = @expected.select { |r| r[@relation[:name]] =~ /#{@pivot[@relation[:name]]}/ }
      @relation.where(@relation[:name].not_matches(/#{@pivot[@relation[:name]]}/).complement).should have_rows(expected)
    end

    it "finds rows with an in predicate" do
      expected = @expected.select {|r| r[@relation[:age]] >=3 && r[@relation[:age]] <= 20}
      @relation.where(@relation[:age].in(3..20)).should have_rows(expected)
    end

    it "finds rows with an in complement predicate" do
      expected = @expected.select {|r| !(r[@relation[:age]] >=3 && r[@relation[:age]] <= 20)}
      @relation.where(@relation[:age].in(3..20).complement).should have_rows(expected)
    end

    it "finds rows with a not in predicate" do
      expected = @expected.select {|r| !(r[@relation[:age]] >=3 && r[@relation[:age]] <= 20)}
      @relation.where(@relation[:age].not_in(3..20)).should have_rows(expected)
    end

    it "finds rows with a not in complement predicate" do
      expected = @expected.select {|r| r[@relation[:age]] >=3 && r[@relation[:age]] <= 20}
      @relation.where(@relation[:age].not_in(3..20).complement).should have_rows(expected)
    end

    it "finds rows with a polyadic predicate of class Any" do
      expected = @expected.select {|r| [2,4,8,16].include?(r[@relation[:age]])}
      @relation.where(@relation[:age].in_any([2,4], [8, 16])).should have_rows(expected)
    end

    it "finds rows with a polyadic predicate of class Any complement" do
      expected = @expected.select {|r| ![2,4,8,16].include?(r[@relation[:age]])}
      @relation.where(@relation[:age].in_any([2,4], [8, 16]).complement).should have_rows(expected)
    end

    it "finds rows with a polyadic predicate of class All" do
      expected = @expected.select {|r| r[@relation[:name]] =~ /Name/ && r[@relation[:name]] =~ /1/}
      @relation.where(@relation[:name].matches_all(/Name/, /1/)).should have_rows(expected)
    end

    it "finds rows with a polyadic predicate of class All complement" do
      expected = @expected.select {|r| !(r[@relation[:name]] =~ /Name/ && r[@relation[:name]] =~ /1/)}
      @relation.where(@relation[:name].matches_all(/Name/, /1/).complement).should have_rows(expected)
    end
  end

  describe "#order" do
    describe "by one attribute" do
      before :all do
        @expected.sort! { |a, b| a[@relation[:age]] <=> b[@relation[:age]]}.map! {|e| e[@relation[:id]]}
      end

      it "can be specified as ascending order" do
        actual = []
        @relation.order(@relation[:age].asc).each { |r| actual << r[@relation[:id]] }
        actual.should == @expected
      end

      it "can be specified as descending order" do
        actual = []
        @relation.order(@relation[:age].desc).each { |r| actual << r[@relation[:id]] }
        actual.should == @expected.reverse
      end
    end

    describe "by two attributes in two separate calls to #order" do
      before :all do
        @expected = @expected.sort_by { |e| [e[@relation[:name]], e[@relation[:age]]]}.map {|e| e[@relation[:id]]}
      end

      it "can be specified as ascending order" do
        actual = []
        @relation.order(@relation[:age].asc).order(@relation[:name].asc).each { |r| actual << r[@relation[:id]] }
        actual.should == @expected
      end

      it "can be specified as descending order" do
        actual = []
        @relation.order(@relation[:age].desc).order(@relation[:name].desc).each { |r| actual << r[@relation[:id]] }
        actual.should == @expected.reverse
      end
    end

    describe "by two attributes in one call to #order" do
      before :all do
        @expected = @expected.sort_by { |e| [e[@relation[:name]], e[@relation[:age]]]}.map {|e| e[@relation[:id]]}
      end

      it "can be specified as ascending order in one call to #order" do
        actual = []
        @relation.order(@relation[:name].asc, @relation[:age].asc).each { |r| actual << r[@relation[:id]] }
        actual.should == @expected
      end

      it "can be specified as descending order in one call to #order" do
        actual = []
        @relation.order(@relation[:name].desc, @relation[:age].desc).each { |r| actual << r[@relation[:id]] }
        actual.should == @expected.reverse
      end
    end
  end

  describe "#take" do
    it "returns a relation" do
      @relation.take(3).should be_a(Arel::Relation)
    end

    it "returns X items from the collection" do
      length = @expected.length

      @relation.take(3).each do |resource|
        @expected.delete_if { |r| r.tuple == resource.tuple }
      end

      @expected.length.should == length - 3
    end

    it "works with ordering" do
      expected = @expected.sort_by { |r| [r[@relation[:age]], r[@relation[:id]]] }.map { |r| r[@relation[:id]] }
      actual   = @relation.order(@relation[:age].asc, @relation[:id].asc).take(3).map { |r| r[@relation[:id]] }

      actual.should == expected[0,3]
    end
  end

  describe "#skip" do
    it "returns a relation" do
      @relation.skip(3).should be_a(Arel::Relation)
    end

    it "skips X items from the collection" do
      length = @expected.length

      @relation.skip(3).each do |resource|
        @expected.delete_if { |r| r.tuple == resource.tuple }
      end

      @expected.length.should == 3
    end

    it "works with ordering" do
      expected = @expected.sort_by { |r| [r[@relation[:age]], r[@relation[:id]]] }.map { |r| r[@relation[:id]] }
      actual   = @relation.order(@relation[:age].asc, @relation[:id].asc).skip(3).map { |r| r[@relation[:id]] }

      actual.should == expected[3..-1]
    end
  end
end
