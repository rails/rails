require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe 'Relational Algebra' do
  before do
    User = TableRelation.new(:users)
    Photo = TableRelation.new(:photos)
    Camera = TableRelation.new(:cameras)
    user = User.select(User[:id] == 1)
    @user_photos = (user << Photo).on(user[:id] == Photo[:user_id])
  end
  
  it 'simulates User.has_many :photos' do
    @user_photos.to_sql.should == SelectBuilder.new do
      select { all }
      from :users do
        left_outer_join :photos do
          equals { column :users, :id; column :photos, :user_id }
        end
      end
      where do
        equals { column :users, :id; value 1 }
      end
    end
    @user_photos.to_sql.to_s.should be_like("""
      SELECT *
      FROM users
        LEFT OUTER JOIN photos
          ON users.id = photos.user_id
      WHERE
        users.id = 1
    """)
  end
  
  it 'simulating a User.has_many :cameras :through => :photos' do
    user_cameras = (@user_photos << Camera).on(@user_photos[:camera_id] == Camera[:id])
  end
end