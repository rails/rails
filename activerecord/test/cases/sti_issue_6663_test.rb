require 'cases/helper'

class MyLeague < ActiveRecord::Base
  has_many :my_league_groups
  has_many :my_players, :through => :my_league_groups
  has_many :my_groups, :through => :my_players
end

class MyGroup < ActiveRecord::Base
  has_many :my_memberships
  has_many :my_players, :through => :my_memberships
end

class MyLeagueGroup < MyGroup
  belongs_to :my_league
end

class MyPlayerGroup < MyGroup
end

class MyMembership < ActiveRecord::Base
  belongs_to :my_player
  belongs_to :my_group
end

class MyPlayer < ActiveRecord::Base
  has_many :my_memberships
  has_many :my_groups, :through => :my_memberships
end

class STIIssue6663Test < ActiveRecord::TestCase
  def setup
    ActiveRecord::Base.connection.create_table :my_leagues do |t|
    end

    ActiveRecord::Base.connection.create_table :my_players do |t|
    end

    ActiveRecord::Base.connection.create_table :my_groups do |t|
      t.belongs_to :my_league
      t.string :type
    end

    ActiveRecord::Base.connection.create_table :my_memberships do |t|
      t.belongs_to :my_group
      t.belongs_to :my_player
    end

    @league = MyLeague.create!

    @league_group = MyLeagueGroup.new
    @league_group.my_league = @league
    @league_group.save!

    @player_group = MyPlayerGroup.create!

    @player = MyPlayer.create!

    [@league_group, @player_group].each do |group|
      membership = MyMembership.new
      membership.my_player = @player
      membership.my_group = group
      membership.save!
    end

  end

  def test_player_groups_returns_all_groups
    # Because: MyPlayer has_many :my_groups, :through => :my_memberships
    assert_equal [@league_group, @player_group], @player.my_groups
  end

  def test_league_players_returns_all_players
    # Because: MyLeague has_many :my_players, :through => :my_league_groups
    assert_equal [@player], @league.my_players
  end

  def test_league_groups_returns_all_groups
    # Because: MyLeague has_many :my_groups, :through => :my_players
    assert_equal [@league_group, @player_group], @league.my_groups
  end

  def teardown
    ActiveRecord::Base.connection.drop_table :my_leagues
    ActiveRecord::Base.connection.drop_table :my_players
    ActiveRecord::Base.connection.drop_table :my_groups
    ActiveRecord::Base.connection.drop_table :my_memberships
  end
end
