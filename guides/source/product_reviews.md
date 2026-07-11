**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Product Reviews
===============

This guide covers adding Reviews to the e-commerce application you created in
the [Getting Started Guide](getting_started.html). We will use the code from
the [Wishlists Guide](wishlists.html) as a starting place.

After reading this guide, you will know how to:

* Collect reviews
* Calculate average ratings for products
* Filter reviews

--------------------------------------------------------------------------------

Introduction
------------

An e-commerce store isn't complete these days without product reviews. In this
guide, we'll collect reviews for products, average the ratings, and give
customers and admins a way to view and filter the reviews.

Let's get started!

Reviews Model
-------------

Product reviews typically consist of a 1 to 5 star rating and some text the user
wrote about the product.

Let's start by creating the `Review` model to store this data.

```bash
$ bin/rails generate model Review product:belongs_to user:belongs_to rating:integer body:text images:attachments
```

This model has several attributes and associations:

- `product:belongs_to` associates the `Review` with the `Product`
- `user:belongs_to` associates the `Review` with the `User` who created it
- `rating` is an integer that stores the 1-5 star rating
- `body` stores the text description of the review
- `images` stores images using ActiveStorage

### Caches

Before we run this migration, let's modify it to add a couple things to the
`products` table that we'll need.

1. A counter cache to keep track of a product's total number of reviews
2. A rating column to store the product's average rating

Open `db/migrate/<timestamp>_create_reviews.rb` and add these columns:

```ruby#12-13
class CreateReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :reviews do |t|
      t.belongs_to :product, null: false, foreign_key: true
      t.belongs_to :user, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :body, null: false

      t.timestamps
    end

    add_column :products, :reviews_count, :integer, default: 0
    add_column :products, :rating, :decimal, precision: 2, scale: 1, default: 0
  end
end
```

We used `decimal` as the type for `rating` with a couple options to control
how the numbers are stored.

- `precision` is the total number of digits
- `scale` is the number of digits after the decimal

This means we can store up to `9.9`. Two digits in total, with one digit after the
decimal sign.

In the terminal, run the migrations to update the database.

```bash
$ bin/rails db:migrate
== 20260421200530 CreateReviews: migrating ====================================
-- create_table(:reviews)
   -> 0.0036s
-- add_column(:products, :reviews_count, :integer, {default: 0})
   -> 0.0005s
-- add_column(:products, :rating, :decimal, {precision: 2, scale: 1})
   -> 0.0004s
== 20260421200530 CreateReviews: migrated (0.0045s) ===========================
```

Next, let's update the model and validate that every review has a body and rating in `app/models/review.rb`:

```ruby#2,6-7
class Review < ApplicationRecord
  belongs_to :product, counter_cache: true
  belongs_to :user
  has_many_attached :images

  validates :body, presence: true
  validates :rating, presence: true, numericality: { in: 1..5, only_integer: true }
end
```

The `product` association was created by the generator, but we need to add the
counter_cache option so the `reviews_count` column is automatically updated.

The [`numericality`](https://guides.rubyonrails.org/active_record_validations.html#numericality)
validator ensures that ratings are integers between 1 and 5.

### Associations

We also need to add associations to the `Product` and `User` models for reviews.

In `app/models/user.rb`, add the association:

```ruby#4
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :wishlists, dependent: :destroy
```

Do the same in `app/models/product.rb`:

```ruby#4
class Product < ApplicationRecord
  include Notifications

  has_many :reviews, dependent: :destroy
  has_many :subscribers, dependent: :destroy
```

Now we're ready to start collecting product reviews!

## Collecting Reviews

On the product's show page, we can ask customers to write a review and display
all the current reviews. Let's start by letting users create reviews.

### Public Product Reviews Routes

Let's create the routes for product reviews first. Since this is public-facing,
we only need the `new` and `create` actions.

In `config/routes.rb`, add the following inside the `resources :products` block:

```ruby#3
  resources :products do
    resource :wishlist, only: [ :create ], module: :products
    resources :reviews, only: [ :new, :create ], module: :products
    resources :subscribers, only: [ :create ]
```

### Product Reviews Partial

Next, let's create a partial for the reviews to be rendered on the product show
page.

Create `app/views/products/_reviews.html.erb` with the following:

```erb
<section class="reviews">
  <%= link_to "Write a review", new_product_review_path(product) %>
</section>
```

At the bottom of `app/views/products/show.html.erb`, we can render the partial:

```erb
<%= render "reviews", product: @product %>
```

We're passing in the product as context here so the partial knows which product
to render reviews for.

### Add the Reviews Controller

To render the form, we need to create the controller.

Create `app/controllers/products/reviews_controller.rb` with the following:

```ruby
class Products::ReviewsController < ApplicationController
  before_action :set_product

  def new
    @review = Review.new
  end

  private

  def set_product
    @product = Product.find(params[:product_id])
  end
end
```

This controller uses the nested route to look up the `Product` on each request.

### New Review Form

Next, let's add the view for collecting reviews.

Create `app/views/products/reviews/new.html.erb` with the following:

```erb
<h1>Add a review</h1>

<%= form_with model: [@product, @review] do |form| %>
  <fieldset>
    <legend>Rating</legend>
    <div class="rating">
      <% 1.upto(5).each do |i| %>
        <%= form.radio_button :rating, i, required: true, class: "sr-only" %>
        <%= form.label :rating, value: i do %>
          <span aria-hidden="true">★</span>
          <span class="sr-only"><%= pluralize(i, "star") %></span>
        <% end %>
      <% end %>
    </div>
  </fieldset>

  <div>
    <%= form.label :body, style: "display: block;" %>
    <%= form.textarea :body, required: true %>
  </div>

  <div>
    <%= form.label :images, style: "display: block;" %>
    <%= form.file_field :images, multiple: true, accept: "image/*", capture: "environment" %>
  </div>

  <%= form.submit %>
<% end %>
```

We're using a loop to create 5 radio buttons for the different ratings a user
could choose.

For image uploads, we're using a file field with a couple attributes that do the
following:

- `multiple: true` tells the browser to allow multiple file uploads
- `accept: "image/*"` is a browser hint that filters the file selector to only
images
- `capture: "environment"` is used by mobile browsers to enable the camera using
the outward-facing camera

### Styling the Star Rating Input

The stars should be gray by default and turn gold when you select a rating. We
can use a few CSS tricks to make this work like you'd expect.

Add the following to `app/assets/stylesheets/application.css` at the bottom:

```css
/* Remove default styling for fieldset */
fieldset {
  border: 0;
  padding: 0;
  margin: 0;
}

/* Remove default styling for legend */
legend {
  padding: 0;
}

/* Hide text visually but not from screen readers */
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

.rating {
  display: flex;
}

/* Mute all stars by default */
.rating label {
  color: lightgray;
}

/* Highlight the selected/focused/hovered star and all previous ones */
.rating input:is(:checked, :focus) + label,
.rating label:has(~ input:is(:checked, :focus)),
.rating label:hover,
.rating label:has(~ input + label:hover) {
  color: gold;
}

/* Outline visible focused inputs */
.rating input:focus-visible + label {
  outline: .2em solid;
  outline-offset: 2px;
}
```

There are a few things going on here:

1. The ratings display as stars, but screen reader users hear clear indications like `Rating, 1 star, radio button, 1 of 5`
2. The radio buttons are hidden but keyboard accessible
3. When a radio is checked, focused or hovered, the star labels before it are colored gold

CSS allows us to select previous siblings using `:has(~ input:checked)` and `:has(~ input + label:hover)`. This selector targets labels for all the lower stars when the user selects a rating. If they choose 3 stars, the selector colors the stars 1, 2, and 3 with gold.

### Creating Reviews

Next, we need to save reviews in the database when the form is submitted.

Add the `create` action to the controller:

```ruby#8-15,23-25
class Products::ReviewsController < ApplicationController
  before_action :set_product

  def new
    @review = Review.new
  end

  def create
    @review = @product.reviews.new(review_params)
    if @review.save
      redirect_to @product, notice: "Review was created successfully."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def set_product
    @product = Product.find(params[:product_id])
  end

  def review_params
    params.expect(review: [ :rating, :body, images: [] ]).with_defaults(user: Current.user)
  end
end
```

Since we used the Rails authentication generator, this controller is only
accessible to authenticated users. This lets us associate the review with a
`User` automatically by merging it in `review_params` to ensure the association
is always set.

## Displaying Product Reviews

We need to a way to view these product reviews next. Let's use a two-column
layout that shows an overview of ratings on the left and the reviews on the
right.

### Rendering Reviews

First, let's query the reviews in `app/controllers/products_controller.rb`:

```ruby#10
class ProductsController < ApplicationController
  allow_unauthenticated_access

  def index
    @products = Product.all
  end

  def show
    @product = Product.find(params[:id])
    @reviews = @product.reviews.with_attached_images
  end
end
```

[`with_attached_images`](https://api.rubyonrails.org/classes/ActiveStorage/Attached/Model.html#method-i-with_attached_-2A)
allows us to preload all the associated ActiveStorage images for these reviews
to avoid N+1 queries.

Let's update `app/views/products/show.html.erb` to also pass along `@reviews` to
the partial so it knows which reviews to render.

```erb
<%= render "reviews", product: @product, reviews: @reviews %>
```

### Calculating Rating Percentages

Let's add a method to calculate the percentage of reviews at a specific rating.
Given a rating of `4`, this will return the percentage of reviews with a 4 star rating.

Add the following to `app/models/product.rb`:

```ruby#4-6
class Product < ApplicationRecord
  # ...

  def rating_percentage(rating)
    (reviews.where(rating: rating).count.to_f / reviews_count * 100).round
  end
end
```

We can use this to display each rating and their percentage of reviews with that
rating.

### Product Reviews Layout

Let's update `app/views/products/_reviews.html.erb` to display that information
alongside the reviews.

```erb
<section class="reviews">
  <aside>
    <h3>Reviews</h3>

    <% if product.reviews_count > 0 %>
      <div role="img" aria-label="<%= product.rating.round %> out of 5 stars">
        <% 5.times do |i| %>
          <%= tag.span "★", class: (i < product.rating.round ? "gold" : "gray"), aria: { hidden: true } %>
        <% end %>
        <%= product.rating %> out of 5
      </div>

      <div><%= pluralize product.reviews_count, "review" %></div>

      <div>
        <% 5.downto(1).each do |i| %>
          <%= link_to product_path(product, rating: i), class: "review__summary", aria: { label: "#{pluralize(i, "star")} — #{product.rating_percentage(i)}% of reviews" } do %>
            <div aria-hidden="true">
              <div class="review__stars"><%= i %></div>
              <div class="gold">★</div>
              <div class="review__bars">
                <div class="review__bar--background"></div>
                <div class="review__bar" style="width: <%= product.rating_percentage(i) %>%;"></div>
              </div>
              <div class="review__percentage"><%= product.rating_percentage(i) %>%</div>
            </div>
          <% end %>
        <% end %>
      </div>
    <% else %>
      <p>None yet!</p>
    <% end %>

    <%= link_to "Write a review", new_product_review_path(product) %>
  </aside>

  <div>
    <%= render reviews %>
  </div>
</section>
```

For the review bars, we use a div to display a gray background. Then we overlay
a gold bar with an inline style with the width set to the percentage of reviews
with that rating.

Let's add the CSS for this to get the two-column layout and styling for the
ratings in the sidebar.

Add the following to `app/assets/stylesheets/application.css`:

```css
section.reviews {
  display: grid;
  grid-template-columns: 250px 1fr;
  margin-top: 2rem;
  gap: 2rem;
}

.review__summary {
  display: flex;
  align-items: center;
  margin-top: 0.25rem;
}

.review__stars {
  width: 1rem;
}

.review__bars {
  position: relative;
  flex: 1;
  display: flex;
  margin: 0px 5px;
}
.review__bar--background {
  background:#eee;
  border-radius: 15px;
  flex: 1;
  height: 12px;
}
.review__bar {
  background: gold;
  border-radius: 15px;
  position: absolute;
  inset-block: 0;
}

.review__percentage {
  text-align: right;
  width: 2.5rem;
}

.review {
  padding: 1rem;
}

.review__images {
  margin-top: 1em;
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}
```

### Reviews Partial

Let's add `app/views/reviews/_review.html.erb` so the individual reviews can be
displayed.

```erb
<%= tag.div id: dom_id(review), class: "review" do %>
  <div><%= tag.strong review.user.full_name %></div>
  <div role="img" aria-label="<%= review.rating %> out of 5 stars">
    <% 5.times do |i| %>
      <%= tag.span "★", class: (i < review.rating ? "gold" : "gray"), aria: { hidden: true } %>
    <% end %>
  </div>

  <%= review.body %>

  <% if review.images.attached? %>
    <div class="review__images">
      <% review.images.each do |image| %>
        <%= link_to image, target: :_blank, title: "View full-size image (opens in new tab)", aria: { label: "View full-size image (opens in new tab)" } do %>
          <%= image_tag image.variant(resize_to_limit: [150, 150]), alt: "" %>
        <% end %>
      <% end %>
    </div>
  <% end %>
<% end %>
```

Under the review's author name, the loop counts from 1 to 5 and adds stars that
are marked gray or gold if the number is within the rating for this review.

### Updating the Average Rating Cache

You may have noticed the product's rating is always `0.0 out of 5`.

When reviews are created, we save the rating but we don't actually update the
average rating on the `Product`.

To solve this, we can add a callback to the `Review` model to update the
associated `Product` rating. This works very similarly to a counter cache, but
instead we're calcuating an average.

Let's add the callback to `app/models/review.rb`:

```ruby#9-13
class Review < ApplicationRecord
  belongs_to :product, counter_cache: true
  belongs_to :user
  has_many_attached :images

  validates :body, presence: true
  validates :rating, presence: true, numericality: { in: 1..5, only_integer: true }

  after_commit :update_product_rating

  def update_product_rating
    product.update_column(:rating, product.reviews.average(:rating)&.round(1))
  end
end
```

We're using `after_commit` so this runs after a record has been created,
updated, or destroyed so the average is always up-to-date.

Using `update_column` bypasses validations, callbacks, and timestamp updates on
the `Product` so we can make a fast update to the record without triggering
additional changes.

Try this out by opening the Rails console and calling this method on a review.

```irb
Loading development environment (Rails 8.2.0)
store(dev)> Review.last.update_product_rating
  Review Load (0.1ms)  SELECT "reviews".* FROM "reviews" ORDER BY "reviews"."id" DESC LIMIT 1 /*application='Store'*/
  Product Load (0.0ms)  SELECT "products".* FROM "products" WHERE "products"."id" = 1 LIMIT 1 /*application='Store'*/
  Review Average (0.1ms)  SELECT AVG("reviews"."rating") FROM "reviews" WHERE "reviews"."product_id" = 1 /*application='Store'*/
  Product Update (0.1ms)  UPDATE "products" SET "rating" = 4.0 WHERE "products"."id" = 1 /*application='Store'*/
=> true
```

The logs show it used SQL to calculate the average rating for the product and
updated the product's rating column with the value.

## Filtering reviews

It's helpful to filter reviews to find what's good and bad about a product. Our
sidebar already has links to the product with a query param for filtering the
rating, so let's use that in the controller to filter the reviews to the rating.

In `app/models/review.rb`, add the following scope:

```ruby#6
class Review < ApplicationRecord
  belongs_to :product, counter_cache: true
  belongs_to :user
  has_many_attached :images

  scope :rated, ->(rating) { rating.present? ? where(rating: rating.to_i) : all }

  validates :body, :rating, presence: true

  after_commit :update_product_rating

  def update_product_rating
    product.update_column(:rating, product.reviews.average(:rating)&.round(1))
  end
end
```

This scope accepts a `rating` argument and filters the query to reviews matching
this rating. If nil or an empty string was passed, it will return all reviews.

The scope also handles invalid ratings safely. For example, `rated("foo")` will
call `"foo".to_i` which returns `0` and will return reviews with a rating of 0.
Since `0` is not a valid rating, there will be no reviews returned.

Let's update `app/controllers/products_controller.rb` to use this new scope.

```ruby#10
class ProductsController < ApplicationController
  allow_unauthenticated_access

  def index
    @products = Product.all
  end

  def show
    @product = Product.find(params[:id])
    @reviews = @product.reviews.with_attached_images.rated(params[:rating])
  end
end
```

Passing `params[:rating]` lets users filter reviews with a query param. There
are several things that can happen:

- If the URL contains `?rating=3`, this will only return reviews with a rating
of 3.
- If this `rating` param is empty or missing, it will return all reviews.
- If the rating param has an invalid value like `?rating=foo`, it will return
no reviews.

Let's update `app/views/products/_reviews.html.erb` to display the filter and a
way to clear it.

```erb#7-13
<section class="reviews">
  <aside>
    <%# ... %>
  </aside>

  <div>
    <% if params[:rating] %>
      <div>
        Filtered by <%= pluralize params[:rating].to_i, "star" %>.
        <%= link_to "Clear filter", product %>
      </div>
    <% end %>

    <%= render reviews %>
  </div>
</section>
```

Test out filtering by clicking on a rating on the left to filter reviews. Use
the "Clear filter" link to show all reviews.

## Managing reviews

Admins need the ability to delete spam reviews, fix typos, and correct other
mistakes. Let's build that next.

To start, let's add a resources route in `config/routes.rb` in the store
namespace for reviews.

```ruby#4
# Admins Only
namespace :store do
  resources :products
  resources :reviews
  resources :users
  resources :wishlists
  resources :subscribers
end
```

We can then implement the controller for this in
`app/controllers/store/reviews_controller.rb`:

```ruby
class Store::ReviewsController < Store::BaseController
  before_action :set_review, except: [ :index ]

  def index
    @reviews = Review.includes(:product, :user).with_attached_images.filter_by(params)
  end

  def show
  end

  def edit
  end

  def update
    if @review.update(review_params)
      redirect_to store_review_path(@review)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @review.destroy
    redirect_to store_reviews_path
  end

  private

  def set_review
    @review = Review.find(params[:id])
  end

  def review_params
    params.expect(review: [ :rating, :body, images: [] ])
  end
end
```

To allow the index to filter by ratings, products, and users, let's add a
`filter_by` method like we did for the `Wishlist` model.

Add the following to `app/models/review.rb`:

```ruby#13-19
class Review < ApplicationRecord
  belongs_to :product, counter_cache: true
  belongs_to :user
  has_many_attached :images

  scope :rated, ->(rating) { rating.present? ? where(rating: rating.to_i) : all }

  validates :body, presence: true
  validates :rating, presence: true, numericality: { in: 1..5, only_integer: true }

  after_commit :update_product_rating

  def self.filter_by(params)
    results = rated(params[:rating])
    results = results.where(product_id: params[:product_id]) if params[:product_id].present?
    results = results.where(user_id: params[:user_id]) if params[:user_id].present?
    results
  end

  def update_product_rating
    product.update_column(:rating, product.reviews.average(:rating)&.round(1))
  end
end
```

### Sidebar Link

To access reviews in the navigation, let's add a link to the sidebar in the
layout.

Add the following to `app/views/layouts/settings.html.erb`:

```erb#13
<%= content_for :content do %>
  <section class="settings">
    <nav>
      <h4>Account Settings</h4>
      <%= link_to "Profile", settings_profile_path %>
      <%= link_to "Email", settings_email_path %>
      <%= link_to "Password", settings_password_path %>
      <%= link_to "Account", settings_user_path %>

      <% if Current.user.admin? %>
        <h4>Store Settings</h4>
        <%= link_to "Products", store_products_path %>
        <%= link_to "Reviews", store_reviews_path %>
        <%= link_to "Users", store_users_path %>
        <%= link_to "Subscribers", store_subscribers_path %>
        <%= link_to "Wishlists", store_wishlists_path %>
      <% end %>
    </nav>

    <div>
      <%= yield %>
    </div>
  </section>
<% end %>

<%= render template: "layouts/application" %>

```

Let's also add a link to the product's show page in `app/views/store/products/show.html.erb`:

```erb#4
<%# ... %>

<section>
  <%= link_to pluralize(@product.reviews_count, "review"), store_reviews_path(product_id: @product.id) %>
  <%= link_to pluralize(@product.wishlists_count, "wishlist"), store_wishlists_path(product_id: @product.id) %>
  <%= link_to pluralize(@product.subscribers_count, "subscriber"), store_subscribers_path(product_id: @product.id) %>
</section>
```

This will make it easy to jump to a product's reviews in the admin area.

### Index View &amp; Partial

Let's create the index view next in `app/views/store/reviews/index.html.erb`:

```erb
<h1>Reviews</h1>

<%= form_with url: store_reviews_path, method: :get do |form| %>
  <%= form.collection_select :product_id, Product.all, :id, :name, selected: params[:product_id], include_blank: "All Products" %>
  <%= form.select :rating, 5.downto(1).map{ pluralize it, "star" }, selected: params[:rating], include_blank: "All Ratings" %>
  <%= form.collection_select :user_id, User.all, :id, :full_name, selected: params[:user_id], include_blank: "All Users" %>
  <%= form.submit "Filter" %>
<% end %>

<%= render @reviews %>
```

Next, let's create the reviews partial in the store namespace. This will look
very similar to the public version, but with some additional context since we're
viewing reviews for any product.

Create `app/views/store/reviews/_review.html.erb` with the following:

```erb
<%= tag.div id: dom_id(review), class: "review" do %>
  <div><%= link_to review.user.full_name, store_user_path(review.user) %> reviewed <%= link_to review.product.name, store_product_path(review.product) %></div>
  <div role="img" aria-label="<%= review.rating %> out of 5 stars">
    <% 5.times do |i| %>
      <%= tag.span "★", class: (i < review.rating ? "gold" : "gray"), aria: { hidden: true } %>
    <% end %>
  </div>

  <%= review.body %>

  <% if review.images.attached? %>
    <div class="review__images">
      <% review.images.each do |image| %>
        <%= link_to image, target: :_blank, title: "View full-size image (opens in new tab)", aria: { label: "View full-size image (opens in new tab)" } do %>
          <%= image_tag image.variant(resize_to_limit: [150, 150]), alt: "" %>
        <% end %>
      <% end %>
    </div>
  <% end %>

  <div>
    <%= link_to "View review", store_review_path(review) %>
  </div>
<% end %>
```

### Show View

Let's create the show view next in `app/views/store/reviews/show.html.erb`:

```erb
<%= link_to "Back to all reviews", store_reviews_path %>

<h1>Review</h1>

<%= tag.div id: dom_id(@review), class: "review" do %>
  <div><%= link_to @review.user.full_name, store_user_path(@review.user) %> reviewed <%= link_to @review.product.name, store_product_path(@review.product) %></div>
  <div>
    <% 5.times do |i| %>
      <%= tag.span "★", class: (i < @review.rating.round ? "gold" : "gray") %>
    <% end %>
  </div>

  <%= @review.body %>

  <% if @review.images.attached? %>
    <div class="review__images">
      <% @review.images.each do |image| %>
        <%= link_to image_tag(image.variant(resize_to_limit: [150, 150])), image, target: :_blank %>
      <% end %>
    </div>
  <% end %>
<% end %>

<div>
  <%= link_to "Edit", edit_store_review_path(@review) %>
  <%= button_to "Delete", store_review_path(@review), method: :delete, data: {turbo_confirm: "Are you sure?"} %>
</div>
```

### Edit View

Last, but not least, let's create the edit view in `app/views/store/reviews/edit.html.erb`

```erb
<h1>Edit Review</h1>

<%= form_with model: [:store, @review] do |form| %>
  <fieldset>
    <legend>Rating</legend>
    <div class="rating">
      <% 1.upto(5).each do |i| %>
        <%= form.radio_button :rating, i, required: true, class: "sr-only" %>
        <%= form.label :rating, value: i do %>
          <span aria-hidden="true">★</span>
          <span class="sr-only"><%= pluralize(i, "star") %></span>
        <% end %>
      <% end %>
    </div>
  </fieldset>

  <div>
    <%= form.label :body, style: "display: block;" %>
    <%= form.textarea :body, required: true %>
  </div>

  <div>
    <%= form.label :images, style: "display: block;" %>
    <%= form.file_field :images, multiple: true, accept: "image/*", capture: "environment" %>

    <% form.object.images.each do |image| %>
      <div>
        <%= image_tag image.variant(resize_to_limit: [150, 150]) %>
        <%= form.hidden_field :images, value: image.signed_id, multiple: true, id: nil %>
        <button onclick="this.parentElement.remove()">Remove</button>
      </div>
    <% end %>
  </div>

  <%= form.submit %>
<% end %>
```

By default, Rails will replace all of the existing images when a new value is
assigned. To preserve existing images when editing a review, we need to create
hidden fields for each image that's already uploaded. These hidden fields use
the image's `signed_id` to reference the existing ActiveRecord object and also
ensures that it wasn't tampered with. We use `multiple: true` so Rails generates
the correct name to add the `images` param as an array. We also disable the `id`
generated for this fields since it would generate duplicates and we don't need
them.

With that added, store admins can now view, edit, and delete reviews as needed.

## Testing reviews

Before we finish, we should write some tests to ensure that the functionality
we just built works.

### Updating Review Fixtures

Rails generated two `Review` test fixtures for us in
`test/fixtures/reviews.yml`, however we need to update them to point to the
`tshirt` product fixture.

```yaml
five_star:
  product: tshirt
  user: one
  rating: 5
  body: I love this.

four_star:
  product: tshirt
  user: two
  rating: 4
  body: Great quality.
```

Let's also set the correct `rating` on the product fixtures to match their
review ratings.

Update `test/fixtures/products.yml` with the following:

```yaml#4-5,10-11
tshirt:
  name: T-Shirt
  inventory_count: 15
  rating: 4.5
  reviews_count: 2

shoes:
  name: Shoes
  inventory_count: 0
  rating: 0
  reviews_count: 0
```

### Creating Reviews Tests

Let's start simple by writing a test to create a review in `test/models/review_test.rb`

```ruby
require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  test "create review" do
    assert_nothing_raised do
      products(:tshirt).reviews.create!(
        user: users(:one),
        rating: 5,
        body: "I love this product."
      )
    end
  end
end
```

Now run the tests to see it pass:

```bash
$ bin/rails test test/models/review_test.rb
Running 1 tests in a single process (parallelization threshold is 50)
Run options: --seed 42591

# Running:

.

Finished in 0.317256s, 3.1520 runs/s, 3.1520 assertions/s.
1 runs, 1 assertions, 0 failures, 0 errors, 0 skips
```

### Testing Invalid Ratings

Ratings need to be between 1 and 5 stars. Let's add a test for that in
`test/models/review_test.rb` too.

```ruby
test "invalid rating" do
  review = products(:tshirt).reviews.create(
    rating: 0,
    user: users(:one),
    body: "Example"
  )

  refute review.valid?
  assert review.errors.has_key?(:rating)
end
```

For this test, we assert that the review is not valid with a `0` rating and that
`rating` is one of the attributes with errors.

Let's run it:

```bash
$ bin/rails test test/models/review_test.rb
Running 2 tests in a single process (parallelization threshold is 50)
Run options: --seed 19665

# Running:

..

Finished in 0.323206s, 6.1880 runs/s, 9.2820 assertions/s.
2 runs, 3 assertions, 0 failures, 0 errors, 0 skips
```

### Testing Product Average Ratings

Since reviews trigger updates on the associated product, we need to write a test
for that too.

Add the following to `test/models/review_test.rb`:

```ruby
test "updates product rating" do
  product = products(:tshirt)
  assert_equal 4.5, product.rating

  product.reviews.create!(
    rating: 3,
    user: users(:one),
    body: "Love it"
  )

  assert_equal 4, product.rating
end
```

Our product fixture has a rating of `4.5`, so by creating a new 3-star review,
we can assert that our product's new average is `4`.

Run the tests:

```bash
$ bin/rails test test/models/review_test.rb
Running 3 tests in a single process (parallelization threshold is 50)
Run options: --seed 28957

# Running:

...

Finished in 0.347102s, 8.6430 runs/s, 14.4050 assertions/s.
3 runs, 5 assertions, 0 failures, 0 errors, 0 skips
```

### `rated` Scope Test

Another thing we can test is the `rated` scope.

```ruby
test "rated scope" do
  assert_equal Review.where(rating: 5), Review.rated(5)
  assert_equal Review.all, Review.rated(nil)
  assert_empty Review.rated("invalid")
end
```

This test ensures the results are correct for each of the cases we covered
earlier:

- 1-5 rating
- Invalid rating
- Nil or empty rating

Run the tests:

```bash
$ bin/rails test test/models/review_test.rb
Running 4 tests in a single process (parallelization threshold is 50)
Run options: --seed 38054

# Running:

....

Finished in 0.351257s, 11.3877 runs/s, 25.6223 assertions/s.
4 runs, 9 assertions, 0 failures, 0 errors, 0 skips
```

### Review Creation Test

Next, let's add an integration test for a customer creating a review. We'll
start by generating an integration test file.

```bash
$ bin/rails generate integration_test reviews

      invoke  test_unit
      create    test/integration/reviews_test.rb
```

In `test/integrations/reviews_test.rb`, let's add a test that submits a review
as a logged-in user.

```ruby
require "test_helper"

class ReviewsTest < ActionDispatch::IntegrationTest
  test "review a product" do
    product = products(:tshirt)
    sign_in_as users(:one)
    assert_difference "Review.count" do
      post product_reviews_path(product), params: { review: { rating: 3, body: "Example" } }
      assert_redirected_to product
    end
  end
end
```

This test logs in and submits a product review, just like a user would submit in
their browser.

Run this test with the following command:

```bash
$ bin/rails test test/integration/reviews_test.rb
Running 1 tests in a single process (parallelization threshold is 50)
Run options: --seed 18242

# Running:

.

Finished in 0.642394s, 1.5567 runs/s, 6.2267 assertions/s.
1 runs, 4 assertions, 0 failures, 0 errors, 0 skips
```

It passes!

### Filtering Reviews Tests

We also want to test filtering reviews on the frontend. Let's add a new test to
the same integration test file.

```ruby#4,15-21
require "test_helper"

class ReviewsTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  test "review a product" do
    product = products(:tshirt)
    sign_in_as users(:one)
    assert_difference "Review.count" do
      post product_reviews_path(product), params: { review: { rating: 3, body: "Example" } }
      assert_redirected_to product
    end
  end

  test "filter product reviews" do
    get product_path(products(:tshirt), rating: 5)
    assert_response :success
    assert_dom "div", text: "Filtered by 5 stars. Clear filter"
    assert_dom "#" + dom_id(reviews(:five_star))
    assert_not_dom "#" + dom_id(reviews(:four_star))
  end
end
```

This test loads the product filtered to 5 star ratings. We assert several things
to ensure it worked:

- The page successfully loaded
- The page contains the filter text and link to clear the filter
- The page contains the 5 star review
- The page _does not_ contain the 4 star review

With those assertions, we can be confident that the review filter was applied
correctly.

```bash
$ bin/rails test test/integration/reviews_test.rb
Running 2 tests in a single process (parallelization threshold is 50)
Run options: --seed 9516

# Running:

..

Finished in 0.720307s, 2.7766 runs/s, 11.1064 assertions/s.
2 runs, 8 assertions, 0 failures, 0 errors, 0 skips
```

### Review Management Tests

Let's finish up by adding a couple tests to ensure that only admins can access
the review management section in the admin area.

We already have an integration test file for this, so we'll add the following
to `test/integration/settings_test.rb`

```ruby
test "regular user cannot access /store/reviews" do
  sign_in_as users(:one)
  get store_reviews_path
  assert_response :redirect
  assert_equal "You aren't allowed to do that.", flash[:alert]
end

test "admin can access /store/reviews" do
  sign_in_as users(:admin)
  get store_reviews_path
  assert_response :success
end
```

Let's run these new tests:

```bash
$ bin/rails test test/integration/settings_test.rb
Running 8 tests in a single process (parallelization threshold is 50)
Run options: --seed 41516

# Running:

........

Finished in 0.689592s, 11.6011 runs/s, 18.8517 assertions/s.
8 runs, 13 assertions, 0 failures, 0 errors, 0 skips
```

Great!

We should also run the entire test suite to ensure everything passes.

```bash
$ bin/rails test
Running 40 tests in a single process (parallelization threshold is 50)
Run options: --seed 27614

# Running:

........................................

Finished in 1.865963s, 21.4367 runs/s, 55.7353 assertions/s.
40 runs, 104 assertions, 0 failures, 0 errors, 0 skips
```

## Deploying to Production

Now that we're finished adding product reviews, let's deploy them to production.
Commit and push your changes to the Git repository and then run:

```bash
$ bin/kamal deploy
```

## What's Next

Your e-commerce store now has product reviews to help customers make more
informed decisions about your products!

Here are a few ideas to build on to this:

- Write more tests
- Finish translating the app into another language
- Add a carousel for product images
- Improve the design with CSS
- Add payments to buy products
- Limit the number of reviews displayed on the product page

Happy building!

[Return to all tutorials](https://rubyonrails.org/docs/tutorials)
