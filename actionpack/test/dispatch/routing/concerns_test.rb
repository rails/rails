# frozen_string_literal: true

require "abstract_unit"

class ReviewsController < ResourcesController; end

class RoutingConcernsTest < ActionDispatch::IntegrationTest
  class Reviewable
    def self.call(mapper, options = {})
      mapper.resources :reviews, options
    end
  end

  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      concern :commentable do |options|
        resources :comments, options
      end

      concern :image_attachable do
        resources :images, only: :index
      end

      concern :reviewable, Reviewable

      resources :posts, concerns: [:commentable, :image_attachable, :reviewable] do
        resource :video, concerns: :commentable do
          concerns :reviewable, as: :video_reviews
        end
      end

      resource :picture, concerns: :commentable do
        resources :posts, concerns: :commentable
      end

      scope "/videos" do
        concerns :commentable, except: :destroy
      end
    end
  end

  include Routes.url_helpers
  APP = RoutedRackApp.new Routes
  def app; APP end

  def test_accessing_concern_from_resources
    get "/posts/1/comments"
    assert_equal "200", @response.code
    assert_equal "/posts/1/comments", post_comments_path(post_id: 1)
  end

  def test_accessing_concern_from_resource
    get "/picture/comments"
    assert_equal "200", @response.code
    assert_equal "/picture/comments", picture_comments_path
  end

  def test_accessing_concern_from_nested_resource
    get "/posts/1/video/comments"
    assert_equal "200", @response.code
    assert_equal "/posts/1/video/comments", post_video_comments_path(post_id: 1)
  end

  def test_accessing_concern_from_nested_resources
    get "/picture/posts/1/comments"
    assert_equal "200", @response.code
    assert_equal "/picture/posts/1/comments", picture_post_comments_path(post_id: 1)
  end

  def test_accessing_concern_from_resources_with_more_than_one_concern
    get "/posts/1/images"
    assert_equal "200", @response.code
    assert_equal "/posts/1/images", post_images_path(post_id: 1)
  end

  def test_accessing_concern_from_resources_using_only_option
    get "/posts/1/image/1"
    assert_equal "404", @response.code
  end

  def test_accessing_callable_concern_
    get "/posts/1/reviews/1"
    assert_equal "200", @response.code
    assert_equal "/posts/1/reviews/1", post_review_path(post_id: 1, id: 1)
  end

  def test_callable_concerns_accept_options
    get "/posts/1/video/reviews/1"
    assert_equal "200", @response.code
    assert_equal "/posts/1/video/reviews/1", post_video_video_review_path(post_id: 1, id: 1)
  end

  def test_accessing_concern_from_a_scope
    get "/videos/comments"
    assert_equal "200", @response.code
  end

  def test_concerns_accept_options
    delete "/videos/comments/1"
    assert_equal "404", @response.code
  end

  def test_with_an_invalid_concern_name
    e = assert_raise ArgumentError do
      ActionDispatch::Routing::RouteSet.new.tap do |app|
        app.draw do
          resources :posts, concerns: :foo
        end
      end
    end

    assert_equal "No concern named foo was found!", e.message
  end
end
