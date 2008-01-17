require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Schmoin do
    before do
      @relation = Table.new(:users)
      photos = Table.new(:photos)
      @aggregate_relation = photos.project(photos[:user_id], photos[:id].count).group(photos[:user_id]).as(:photo_count)
      @predicate = Equality.new(@aggregate_relation[:user_id], @relation[:id])
    end
  
    describe '#to_sql' do
      it 'manufactures sql joining the two tables on the predicate, merging the selects' do
        pending
        Schmoin.new("INNER JOIN", @relation, @aggregate_relation, @predicate).to_sql.should be_like("""
          SELECT `users`.`name`
          FROM `users`
            INNER JOIN (SELECT `photos`.`user_id`, count(`photos`.`id`) FROM `photos`) AS `photo_count`
              ON `photo_count`.`user_id` = `users`.`id`
        """)
      end
    end
  end
end