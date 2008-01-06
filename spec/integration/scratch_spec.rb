require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe 'Relational Algebra' do
  before do
    @users = TableRelation.new(:users)
    @photos = TableRelation.new(:photos)
    @cameras = TableRelation.new(:cameras)
    @user = @users.select(@users[:id] == 1)
    @user_photos = (@user << @photos).on(@user[:id] == @photos[:user_id])
    @user_cameras = (@user_photos << @cameras).on(@user_photos[:camera_id] == @cameras[:id])
  end
  
  it 'simulates User.has_many :photos' do
    @user_photos.project(*@photos.attributes).to_s.should be_like("""
      SELECT `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`
      FROM `users`
        LEFT OUTER JOIN `photos`
          ON `users`.`id` = `photos`.`user_id`
      WHERE
        `users`.`id` = 1
    """)
  end
  
  it 'simulates a User.has_many :cameras :through => :photos' do
    @user_cameras.project(*@cameras.attributes).to_s.should be_like("""
      SELECT `cameras`.`id`
      FROM `users`
        LEFT OUTER JOIN `photos`
          ON `users`.`id` = `photos`.`user_id`
        LEFT OUTER JOIN `cameras`
          ON `photos`.`camera_id` = `cameras`.`id`
      WHERE
        `users`.`id` = 1
    """)
  end
  
  it '' do
    # p @user_cameras.qualify.to_s
    # 
    # @users.rename()
  end
end