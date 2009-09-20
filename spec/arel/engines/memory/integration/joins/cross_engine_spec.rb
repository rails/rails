require 'spec_helper'

module Arel
  describe Join do
    before do
      @users = Array.new([
        [1, 'bryan' ],
        [2, 'emilio' ],
        [3, 'nick']
      ], [:id, :name])
      @photos = Table.new(:photos)
      @photos.delete
      @photos.insert(@photos[:id] => 1, @photos[:user_id] => 1, @photos[:camera_id] => 6)
      @photos.insert(@photos[:id] => 2, @photos[:user_id] => 2, @photos[:camera_id] => 42)
    end

    describe 'when the in memory relation is on the left' do
      it 'joins across engines' do
        @users                                         \
          .join(@photos)                               \
            .on(@users[:id].eq(@photos[:user_id]))     \
          .project(@users[:name], @photos[:camera_id]) \
        .let do |relation|
          relation.call.should == [
            Row.new(relation, ['bryan', '6']),
            Row.new(relation, ['emilio', '42'])
          ]
        end
      end
    end

    describe 'when the in memory relation is on the right' do
      it 'joins across engines' do
        @photos                                        \
          .join(@users)                                \
            .on(@users[:id].eq(@photos[:user_id]))     \
          .project(@users[:name], @photos[:camera_id]) \
        .let do |relation|
          relation.call.should == [
            Row.new(relation, ['bryan', '6']),
            Row.new(relation, ['emilio', '42'])
          ]
        end
      end
    end
  end
end
