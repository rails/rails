require "isolation/abstract_unit"
require "active_support/core_ext/string/strip"

class RakeTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
  end

  def teardown
    teardown_app
  end

  def test_singular_resource_output_in_rake_routes
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        resource :post
      end
    RUBY
    expected_output = ["   Prefix Verb   URI Pattern          Controller#Action",
                       " new_post GET    /post/new(.:format)  posts#new",
                       "edit_post GET    /post/edit(.:format) posts#edit",
                       "     post GET    /post(.:format)      posts#show",
                       "          PATCH  /post(.:format)      posts#update",
                       "          PUT    /post(.:format)      posts#update",
                       "          DELETE /post(.:format)      posts#destroy",
                       "          POST   /post(.:format)      posts#create\n"].join("\n")

    output = Dir.chdir(app_path) { `bin/rails routes -c PostController` }
    assert_equal expected_output, output
  end
end
