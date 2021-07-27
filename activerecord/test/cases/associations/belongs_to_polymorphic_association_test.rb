# frozen_string_literal: true

require "cases/helper"
require "models/review"
require "models/show"
require "models/album"
require "models/manga"
require "models/restaurant"
require "models/restaurant/menu"
require "models/library"
require "models/library/staff_member"

class BelongsToPolymorphicAssociationTest < ActiveRecord::TestCase
  fixtures :reviews, :albums, :shows, :mangas, :restaurants, "restaurant/menus", :libraries, "library/staff_members"

  setup do
    @album_review      = reviews(:album_review)
    @show_review       = reviews(:show_review)
    @manga_review      = reviews(:manga_review)
    @restaurant_review = reviews(:restaurant_review)
    @menu_review       = reviews(:menu_review)
    @library_review    = reviews(:library_review)
    @staff_review      = reviews(:staff_review)
  end

  test "should be able to use aliases to access polymorphic associations" do
    assert_equal "This album is crushin!", @album_review.content
    assert_equal "The Off-Season", @album_review.album.name

    assert_equal "So disappointed by the end...", @show_review.content
    assert_equal "Game Of Thrones", @show_review.show.name

    assert_equal "Masterpiece", @manga_review.content
    assert_equal "Shingeki No Kyojin", @manga_review.manga.name

    assert_equal "We can chill to code without buying. That's neat!", @restaurant_review.content
    assert_equal "La Felicità", @restaurant_review.restaurant.name

    assert_equal "Not for me", @menu_review.content
    assert_equal "Happy Meal", @menu_review.restaurant_menu.name

    assert_equal "Awesome library! They're even lending robots to teach kids how to code!", @library_review.content
    assert_equal "L'Eclipse", @library_review.library.name

    assert_equal "The Best One!", @staff_review.content
    assert_equal "Dorothy", @staff_review.library_staff_member.name

    assert @album_review.reload_album
    assert @show_review.reload_show
    assert @manga_review.reload_manga
    assert @restaurant_review.reload_restaurant
    assert @menu_review.reload_restaurant_menu
    assert @library_review.reload_library
    assert @staff_review.reload_library_staff_member

    assert_nil @album_review.show
    assert_nil @show_review.restaurant_menu
    assert_nil @manga_review.library_staff_member
    assert_nil @restaurant_review.manga
    assert_nil @menu_review.library
    assert_nil @library_review.restaurant
    assert_nil @staff_review.album
  end
end
