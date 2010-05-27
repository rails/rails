require 'spec_helper'
require 'bigdecimal'

module Arel
  describe "Attributes::Time" do

    before :all do
      @relation = Model.build do |r|
        r.engine Testing::Engine.new
        r.attribute :created_at, Attributes::Time
      end
    end

    def type_cast(val)
      @relation[:created_at].type_cast(val)
    end

    describe "#type_cast" do
      it "works" do
        pending
      end
    end
  end
end
