**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Wishlists
=========

This guide covers adding Wishlists to the e-commerce application you created in the
[Getting Started Guide](getting_started.html)). We will use the code from the
[Sign up and Settings Guide](sign_up_and_settings.html) as a starting place.

After reading this guide, you will know how to:

* Add wishlists
* Use counter caches
* Add friendly URLs
* Filter records

--------------------------------------------------------------------------------

Introduction
------------

E-commerce stores often have wishlists for sharing products. Customers can use
wishlists to keep track of products they'd like to buy or share them with
friends and family for gift ideas.

Let's get started!

Wishlist Models
---------------

Our e-commerce store has products and users that we already built in the previous
tutorials. These are the foundations we need to build Wishlists. Each wishlist
belongs to a user and contains a list of products.

Let's start by creating the `Wishlist` model.

```bash
$ bin/rails generate model Wishlist user:belongs_to name products_count:integer
```

This model has 3 attributes:

- `user:belongs_to` which associates the `Wishlist` with the `User` who
  owns it
- `name` which we'll also use for friendly URLs
- `products_count` for the [counter cache](https://guides.rubyonrails.org/association_basics.html#counter-cache) to count how many products
  are on the Wishlist

To associate a `Wishlist` with multiple `Products`, we need to add a table to
join them.

```bash
$ bin/rails generate model WishlistProduct product:belongs_to wishlist:belongs_to
```

We don't want the same `Product` to be on a `Wishlist` multiple times, so let's
add an index to the migration that was just created:

```ruby#10
class CreateWishlistProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :wishlist_products do |t|
      t.belongs_to :product, null: false, foreign_key: true
      t.belongs_to :wishlist, null: false, foreign_key: true

      t.timestamps
    end

    add_index :wishlist_products, [:product_id, :wishlist_id], unique: true
  end
end
```

Finally, let's add a counter to the `Product` model to keep track of how many
`Wishlists` the product is on.

```bash
$ bin/rails generate migration AddWishlistsCountToProducts wishlists_count:integer
```

### Default Counter Cache Values

Before we run these new migrations, let's set a default value for the counter
cache columns so that all existing records start with a count of zero instead of NULL.

Open the `db/migrate/<timestamp>_create_wishlists.rb` migration and add the
default option:

```ruby#6
class CreateWishlists < ActiveRecord::Migration[8.0]
  def change
    create_table :wishlists do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.string :name
      t.integer :products_count, default: 0

      t.timestamps
    end
  end
end
```

Then open `db/migrate/<timestamp>_add_wishlists_count_to_products.rb` and add a
default here too:

```ruby#3
class AddWishlistsCountToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :wishlists_count, :integer, default: 0
  end
end
```

Now let's run the migrations:

```bash
$ bin/rails db:migrate
```

### Associations & Counter Caches

Now that our database tables are created, let's update our models in Rails to
include these new associations.

In `app/models/user.rb`, add the following:

```ruby#4
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :wishlists, dependent: :destroy

  # ...
```

We set `dependent: :destroy` on the `wishlists` association so when a User is
deleted, their wishlists are deleted too.

Then in `app/models/product.rb`, add:

```ruby#4-5
class Product < ApplicationRecord
  include Notifications

  has_many :wishlist_products, dependent: :destroy
  has_many :wishlists, through: :wishlist_products
  has_one_attached :featured_image
  has_rich_text :description
```

We added two associations to `Product`. First, we associate the `Product` model
with the `WishlistProduct` join table. Using this join table, our second
association tells Rails that a `Product` is a part of many `Wishlists` through
the same `WishlistProduct` join table. From a `Product` record, we can directly
access the `Wishlists` and Rails will know to automatically `JOIN` the tables in
SQL queries.

We also set `wishlist_products` as `dependent: :destroy`. When a `Product` is
destroyed, it will be automatically removed from any Wishlists.

A counter cache stores the number of associated records to avoid running a separate query each time the count is needed. So in `app/models/wishlist_product.rb`, let's update both associations to enable counter
caching:

```ruby#2-5
class WishlistProduct < ApplicationRecord
  belongs_to :product, counter_cache: :wishlists_count
  belongs_to :wishlist, counter_cache: :products_count

  validates :product_id, uniqueness: { scope: :wishlist_id }
end
```

We've specified a column name to update on the associated models. For the
`Product` model, we want to use the `wishlists_count` column and for `Wishlist` we
want to use `products_count`. These counter caches update anytime a
`WishlistProduct` is created or destroyed.

The `uniqueness` validation also tells Rails to check if a product is already on
the wishlist. This is paired with the unique index on the wishlist_product table
so that it's also validated at the database level.

Finally, let's update `app/models/wishlist.rb` with it's associations:

```ruby
class Wishlist < ApplicationRecord
  belongs_to :user
  has_many :wishlist_products, dependent: :destroy
  has_many :products, through: :wishlist_products
end
```

Just like with `Product`, `wishlist_products` uses the `dependent: :destroy`
option to automatically remove join table records when a Wishlist is deleted.

### Friendly URLs

Wishlists are often shared with friends and family. By default, the ID in the
URL for a `Wishlist` is a simple Integer. This means we can't easily look at the
URL to determine which `Wishlist` it's for.

Active Record has a `to_param` class method that can be used for generating more descriptive
URLs. Let's try it out in our model:

```ruby#6-8
class Wishlist < ApplicationRecord
  belongs_to :user
  has_many :wishlist_products, dependent: :destroy
  has_many :products, through: :wishlist_products

  def to_param
    "#{id}-#{name.squish.parameterize}"
  end
end
```

This will create a `to_param`  instance method that returns a String for the URL param made up of the `id` and `name` joined by
hyphens. `name` is made URL safe by using
[`squish`](https://api.rubyonrails.org/classes/String.html#method-i-squish) to
clean up whitespace and
[`parameterize`](https://api.rubyonrails.org/classes/String.html#method-i-parameterize)
to replace special characters.

Let's test this in the Rails console:

```bash
$ bin/rails console
```

Then create a `Wishlist` for your `User` in the database:

```irb
store(dev)> user = User.first
store(dev)> wishlist = user.wishlists.create!(name: "Example Wishlist")
store(dev)> wishlist.to_param
=> "1-example-wishlist"
```

Perfect!

Now let's try finding this record using this param:

```irb
store(dev)> wishlist = Wishlist.find("1-example-wishlist")
=> #<Wishlist:0x000000012bb71d68
 id: 1,
 user_id: 1,
 name: "Example Wishlist",
 products_count: nil,
 created_at: "2025-07-22 15:21:29.036470000 +0000",
 updated_at: "2025-07-22 15:21:29.036470000 +0000">
```

It worked! But how? Didn't we have to use Integers to find records?

The way we're using `to_param` takes advantage of [how Ruby converts Strings to
Integers](https://docs.ruby-lang.org/en/master/String.html#method-i-to_i). Let's convert that param to an integer using `to_i` in the console:

```irb
store(dev)> "1-example-wishlist".to_i
=> 1
```

Ruby parses the String until it finds a character that isn't a valid number. In
this case, it stops at the first hyphen. Then Ruby converts the String of `"1"`
into an Integer and returns `1`. This makes `to_param` work seamlessly when
prefixing the ID at the beginning.

Now that we understand how this works, let's replace our `to_param` method with
a call to the class method shortcut.

```ruby#6
class Wishlist < ApplicationRecord
  belongs_to :user
  has_many :wishlist_products, dependent: :destroy
  has_many :products, through: :wishlist_products

  to_param :name
end
```

The
[`to_param`](https://edgeapi.rubyonrails.org/classes/ActiveRecord/Integration/ClassMethods.html#method-i-to_param)
class method defines an instance method with the same name. The argument is the
method name to be called for generating the param. We're telling it to use the
`name` attribute to generate the param.

One additional thing `to_param` does is truncate values longer than 20
characters word by word.

Let's reload our code in the Rails console and test out a long `Wishlist` name.

```irb
store(dev)> reload!
store(dev)> Wishlist.last.update(name: "A really, really long wishlist name!")
store(dev)> Wishlist.last.to_param
=> "1-a-really-really-long"
```

You can see that the name was truncated to the closest word to 20 characters.

Alright, close the Rails console and let's start implementing wishlists in the UI.

## Adding Products To Wishlists

The first place a user will probably use wishlists is on the `Product` show page.
They'll likely be browsing products and want to save one for later. Let's begin
by building that first.

### Add To Wishlist Form

Start in `config/routes.rb` by adding the route for this form to submit to:

```ruby#2
  resources :products do
    resource :wishlist, only: [ :create ], module: :products
    resources :subscribers, only: [ :create ]
  end
```

We're using a singular resource for this route since we won't necessarily know
the Wishlist ID ahead of time. We're also using `module: :products` to scope
this controller to the `Products` namespace.

In `app/views/products/show.html.erb`, add the following to render a new
wishlist partial:

```erb#13
<p><%= link_to "Back", products_path %></p>

<section class="product">
  <%= image_tag @product.featured_image if @product.featured_image.attached? %>

  <section class="product-info">
    <% cache @product do %>
      <h1><%= @product.name %></h1>
      <%= @product.description %>
    <% end %>

    <%= render "inventory", product: @product %>
    <%= render "wishlist", product: @product %>
  </section>
</section>
```

Then create `app/views/products/_wishlist.html.erb` with the following:

```erb
<% if authenticated? %>
  <%= form_with url: product_wishlist_path(product) do |form| %>
    <div>
      <%= form.collection_select :wishlist_id, Current.user.wishlists, :id, :name %>
    </div>

    <div>
      <%= form.submit "Add to wishlist" %>
    </div>
  <% end %>
<% else %>
  <%= link_to "Add to wishlist", sign_up_path %>
<% end %>
```

If a user is not logged in, they'll see a link to sign up. Logged in users will
see a form to select a wishlist and add the product to it.

Next, create the controller to handle this form in
`app/controllers/products/wishlists_controller.rb` with the following:

```ruby
class Products::WishlistsController < ApplicationController
  before_action :set_product
  before_action :set_wishlist

  def create
    @wishlist.wishlist_products.create(product: @product)
    redirect_to @wishlist, notice: "#{@product.name} added to wishlist."
  end

  private
    def set_product
      @product = Product.find(params[:product_id])
    end

    def set_wishlist
      @wishlist = Current.user.wishlists.find(params[:wishlist_id])
    end
end
```

Since we're in a nested resource route, we find the `Product` using the
`:product_id` param.

The `create` action is also simpler than normal. If a product is already on the
wishlist, the `wishlist_product` record will fail to create but we don't need to
notify the user of this error so we can redirect to the wishlist in either case.

Now, log in as the user we created a wishlist for earlier and try adding a product to the
wishlist.

### Default Wishlist

This works fine since we created a wishlist in the Rails console, but what
happens when the user doesn't have any wishlists?

Run the following to delete all wishlists in the database:

```bash
$ bin/rails runner "Wishlist.destroy_all"
```

Try visiting a product and adding it to a wishlist now.

The first problem is the select box will be empty. The form will not submit a
`wishlist_id` param to the server and that will cause Active Record to raise an
error.

```bash
ActiveRecord::RecordNotFound (Couldn't find Wishlist without an ID):

app/controllers/products/wishlists_controller.rb:16:in 'Products::WishlistsController#set_wishlist'
```

In this case, we should automatically create a wishlist if the user doesn't have
any. This has the added bonus of slowly introducing the user to wishlists.

Update `set_wishlist` in the controller to find or create a wishlist:

```ruby#16-20
class Products::WishlistsController < ApplicationController
  before_action :set_product
  before_action :set_wishlist

  def create
    @wishlist.wishlist_products.create(product: @product)
    redirect_to @wishlist, notice: "#{@product.name} added to wishlist."
  end

  private
    def set_product
      @product = Product.find(params[:product_id])
    end

    def set_wishlist
      if (id = params[:wishlist_id])
        @wishlist = Current.user.wishlists.find(id)
      else
        @wishlist = Current.user.wishlists.create(name: "My Wishlist")
      end
    end
end
```

To improve our form, let's hide the select box if the user doesn't have any
wishlists. Update `app/views/products/_wishlist.html.erb` with the following:

```erb#3,7
<% if authenticated? %>
  <%= form_with url: product_wishlist_path(product) do |form| %>
    <% if Current.user.wishlists.any? %>
      <div>
        <%= form.collection_select :wishlist_id, Current.user.wishlists, :id, :name %>
      </div>
    <% end %>

    <div>
      <%= form.submit "Add to wishlist" %>
    </div>
  <% end %>
<% else %>
  <%= link_to "Add to wishlist", sign_up_path %>
<% end %>
```

## Managing Wishlists

Next, we need to be able to view and manage our wishlists.

### Wishlists Controller

Start by adding a route for wishlists at the top level:

```ruby#9
Rails.application.routes.draw do
  # ...
  resources :products do
    resource :wishlist, only: [ :create ], module: :products
    resources :subscribers, only: [ :create ]
  end
  resource :unsubscribe, only: [ :show ]

  resources :wishlists
```

Then we can add the controller at `app/controllers/wishlists_controller.rb` with
the following:

```ruby
class WishlistsController < ApplicationController
  allow_unauthenticated_access only: %i[ show ]
  before_action :set_wishlist, only: %i[ edit update destroy ]

  def index
    @wishlists = Current.user.wishlists
  end

  def show
    @wishlist = Wishlist.find(params[:id])
  end

  def new
    @wishlist = Wishlist.new
  end

  def create
    @wishlist = Current.user.wishlists.new(wishlist_params)
    if @wishlist.save
      redirect_to @wishlist, notice: "Your wishlist was created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @wishlist.update(wishlist_params)
      redirect_to @wishlist, status: :see_other, notice: "Your wishlist has been updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @wishlist.destroy
    redirect_to wishlists_path, status: :see_other
  end

  private

  def set_wishlist
    @wishlist = Current.user.wishlists.find(params[:id])
  end

  def wishlist_params
    params.expect(wishlist: [ :name ])
  end
end
```

This is a very standard controller with a couple important changes:

- Actions are scoped to `Current.user.wishlists` so only the owner can create,
  update, and delete their own wishlists
- `show` is publicly accessible so wishlists can be shared and viewed by anyone

### Wishlist Views

Create the index view at `app/views/wishlists/index.html.erb`:

```erb
<h1>Your Wishlists</h1>
<%= link_to "Create a wishlist", new_wishlist_path %>
<%= render @wishlists %>
```

This renders the `_wishlist` partial so let's create that at
`app/views/wishlists/_wishlist.html.erb`:

```erb
<div>
  <%= link_to wishlist.name, wishlist %>
</div>
```

Next let's create the `new` view at `app/views/wishlists/new.html.erb`:

```erb
<h1>New Wishlist</h1>
<%= render "form", locals: { wishlist: @wishlist } %>
```

And the `edit` view at `app/views/wishlists/edit.html.erb`:

```erb
<h1>Edit Wishlist</h1>
<%= render "form", locals: { wishlist: @wishlist } %>
```

Along with the `_form` partial at `app/views/wishlists/_form.html.erb`:

```erb
<%= form_with model: @wishlist do |form| %>
  <% if form.object.errors.any? %>
    <div><%= form.object.errors.full_messages.to_sentence %></div>
  <% end %>

  <div>
    <%= form.label :name %>
    <%= form.text_field :name %>
  </div>

  <div>
    <%= form.submit %>
    <%= link_to "Cancel", form.object.persisted? ? form.object : wishlists_path %>
  </div>
<% end %>
```

Create `show` next at `app/views/wishlists/show.html.erb`:

```erb
<h1><%= @wishlist.name %></h1>
<% if authenticated? && @wishlist.user == Current.user %>
  <%= link_to "Edit", edit_wishlist_path(@wishlist) %>
  <%= button_to "Delete", @wishlist, method: :delete, data: { turbo_confirm: "Are you sure?" } %>
<% end %>

<h3><%= pluralize @wishlist.products_count, "Product" %></h3>
<% @wishlist.wishlist_products.includes(:product).each do %>
  <div>
    <%= link_to it.product.name, it.product %>
    <small>Added <%= l it.created_at, format: :long %></small>
  </div>
<% end %>
```

Lastly, let's add a link to the navbar in
`app/views/layouts/application.html.erb`:

```erb#4
    <nav class="navbar">
      <%= link_to "Home", root_path %>
      <% if authenticated? %>
        <%= link_to "Wishlists", wishlists_path %>
        <%= link_to "Settings", settings_root_path %>
        <%= button_to "Log out", session_path, method: :delete %>
      <% else %>
        <%= link_to "Sign Up", sign_up_path %>
        <%= link_to "Login", new_session_path %>
      <% end %>
    </nav>
```

Refresh the page and click the "Wishlists" link in the navbar to view and manage your
wishlists.

### Copy To Clipboard

To make sharing wishlists easier, we can add a “Copy to Clipboard” button that uses a small amount of JavaScript.

Rails includes Hotwire by default, so we can use its [Stimulus framework](https://stimulus.hotwired.dev/)
 to add some lightweight JavaScript to our UI.

First, let's add a button to `app/views/wishlists/show.html.erb`:

```erb#7
<h1><%= @wishlist.name %></h1>
<% if authenticated? && @wishlist.user == Current.user %>
  <%= link_to "Edit", edit_wishlist_path(@wishlist) %>
  <%= button_to "Delete", @wishlist, method: :delete, data: { turbo_confirm: "Are you sure?" } %>
<% end %>

<%= tag.button "Copy to clipboard", data: { controller: :clipboard, action: "clipboard#copy", clipboard_text_value: wishlist_url(@wishlist) } %>
```

This button has several data attributes that wire up to the JavaScript. We're
using the Rails `tag` helper to make this shorter which outputs the following
HTML:

```html
<button data-controller="clipboard" data-action="clipboard#copy" data-clipboard-text-value="/wishlists/1-example-wishlist">
  Copy to clipboard
</button>
```

What do these data attributes do? Let's break down each one:

- `data-controller` tells Stimulus to connect to `clipboard_controller.js`
- `data-action` tells Stimulus to call the
  `clipboard` controller's `copy()` method when the button is clicked
- `data-clipboard-text-value` tells the Stimulus controller it has some data
  called `text` that it can use

Create the Stimulus controller at
`app/javascript/controllers/clipboard_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  copy() {
    navigator.clipboard.writeText(this.textValue)
  }
}
```

This Stimulus controller is short. It does two things:

- Registers `text` as a value so we can access it. This is the URL we want to
  copy to the clipboard.
- The `copy` function writes the `text` from the HTML to the clipboard when
  called.

If you're familiar with JavaScript, you'll notice we didn't have to add any event listeners or setup & teardown this
controller. That's handled automatically by Stimulus reading the data attributes
in our HTML.

To learn more about Stimulus, check out the
[Stimulus](https://stimulus.hotwired.dev/) website.

### Removing Products

A user may purchase or lose interest in a product and want to remove it from
their wishlist. Let's add that feature next.

First we'll update the wishlists route to contain a nested resource.

```ruby#9-11
Rails.application.routes.draw do
  # ...
  resources :products do
    resource :wishlist, only: [ :create ], module: :products
    resources :subscribers, only: [ :create ]
  end
  resource :unsubscribe, only: [ :show ]

  resources :wishlists do
    resources :wishlist_products, only: [ :update, :destroy ], module: :wishlists
  end
```

Then we can update `app/views/wishlists/show.html.erb` to include a "Remove"
button:

```erb#13-15
<h1><%= @wishlist.name %></h1>
<% if authenticated? && @wishlist.user == Current.user %>
  <%= link_to "Edit", edit_wishlist_path(@wishlist) %>
  <%= button_to "Delete", @wishlist, method: :delete, data: { turbo_confirm: "Are you sure?" } %>
<% end %>

<h3><%= pluralize @wishlist.products_count, "Product" %></h3>
<% @wishlist.wishlist_products.includes(:product).each do %>
  <div>
    <%= link_to it.product.name, it.product %>
    <small>Added <%= l it.created_at, format: :long %></small>

    <% if authenticated? && @wishlist.user == Current.user %>
      <%= button_to "Remove", [ @wishlist, it ], method: :delete, data: { turbo_confirm: "Are you sure?" } %>
    <% end %>
  </div>
<% end %>
```

Create `app/controllers/wishlists/wishlist_products_controller.rb` and add the
following:

```ruby
class Wishlists::WishlistProductsController < ApplicationController
  before_action :set_wishlist
  before_action :set_wishlist_product

  def destroy
    @wishlist_product.destroy
    redirect_to @wishlist, notice: "#{@wishlist_product.product.name} removed from wishlist."
  end

  private

  def set_wishlist
    @wishlist = Current.user.wishlists.find_by(id: params[:wishlist_id])
  end

  def set_wishlist_product
    @wishlist_product = @wishlist.wishlist_products.find(params[:id])
  end
end
```

You can now remove products from any wishlist. Try it out!

### Moving Products To Another Wishlist

With multiple wishlists, users may want to move a product from one list to
another. For example, they might want to move items into a "Christmas" wishlist.

In `app/views/wishlists/show.html.erb`, add the following:

```erb#14-19
<h1><%= @wishlist.name %></h1>
<% if authenticated? && @wishlist.user == Current.user %>
  <%= link_to "Edit", edit_wishlist_path(@wishlist) %>
  <%= button_to "Delete", @wishlist, method: :delete, data: { turbo_confirm: "Are you sure?" } %>
<% end %>

<h3><%= pluralize @wishlist.products_count, "Product" %></h3>
<% @wishlist.wishlist_products.includes(:product).each do %>
  <div>
    <%= link_to it.product.name, it.product %>
    <small>Added <%= l it.created_at, format: :long %></small>

    <% if authenticated? && @wishlist.user == Current.user %>
      <% if (other_wishlists = Current.user.wishlists.excluding(@wishlist)) && other_wishlists.any? %>
        <%= form_with url: [ @wishlist, it ], method: :patch do |form| %>
          <%= form.collection_select :new_wishlist_id, other_wishlists, :id, :name %>
          <%= form.submit "Move" %>
        <% end %>
      <% end %>

      <%= button_to "Remove", [ @wishlist, it ], method: :delete, data: { turbo_confirm: "Are you sure?" } %>
    <% end %>
  </div>
<% end %>
```

This queries for other wishlists and, if present, renders a form to move a
product to the selected wishlist. If no other wishlists exist, the form will not
be displayed.

To handle this in the controller, we'll add the `update` action to
`app/controllers/wishlists/wishlist_products_controller.rb`:

```ruby#5-12
class Wishlists::WishlistProductsController < ApplicationController
  before_action :set_wishlist
  before_action :set_wishlist_product

  def update
    new_wishlist = Current.user.wishlists.find(params[:new_wishlist_id])
    if @wishlist_product.update(wishlist: new_wishlist)
      redirect_to @wishlist, status: :see_other, notice: "#{@wishlist_product.product.name} has been moved to #{new_wishlist.name}"
    else
      redirect_to @wishlist, status: :see_other, alert: "#{@wishlist_product.product.name} is already on #{new_wishlist.name}."
    end
  end

  # ...
```

This action looks up the new wishlist from the logged in user's wishlists. It
then tries to update the wishlist ID on `@wishlist_product`. This could fail if
the product already exists on the other wishlist so we'll display an error in
that case. If not, we can simply transfer the product to the new wishlist. Since
we don't want the user to lose their place, we redirect back to the current
wishlist they're viewing in either case.

Test this out by creating a second wishlist and moving a product back and forth.

## Adding Wishlists To Admin

Viewing wishlists in the admin area will be helpful to get an idea of which
products are popular.

To start, let's add wishlists to the store namespace routes in
`config/routes.rb`:

```ruby#5
  # Admins Only
  namespace :store do
    resources :products
    resources :users
    resources :wishlists

    root to: redirect("/store/products")
  end
```

Create `app/controllers/store/wishlists_controller.rb` with:

```ruby
class Store::WishlistsController < Store::BaseController
  def index
    @wishlists = Wishlist.includes(:user)
  end

  def show
    @wishlist = Wishlist.find(params[:id])
  end
end
```

We only need the index and show actions here because as admins, we don't want to
mess with user's wishlists.

Now let's add the views for these actions.
Create `app/views/store/wishlists/index.html.erb` with:

```erb
<h1>Wishlists</h1>
<%= render @wishlists %>
```

Then create the wishlist partial in
`app/views/store/wishlists/_wishlist.html.erb` with:

```erb
<div>
  <%= link_to wishlist.name, store_wishlist_path(wishlist) %> by <%= link_to wishlist.user.full_name, store_user_path(wishlist.user) %>
</div>
```

Then create the show view at `app/views/store/wishlists/show.html.erb` with:

```erb
<h1><%= @wishlist.name %></h1>
<p>By <%= link_to @wishlist.user.full_name, store_user_path(@wishlist.user) %></p>

<h3><%= pluralize @wishlist.products_count, "Product" %></h3>
<% @wishlist.wishlist_products.includes(:product).each do %>
  <div>
    <%= link_to it.product.name, store_product_path(it.product) %>
    <small>Added <%= l it.created_at, format: :long %></small>
  </div>
<% end %>
```

Lastly, add the link to the sidebar layout:

```erb#14
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
        <%= link_to "Users", store_users_path %>
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

Now we can view wishlists in the admin area.

### Filtering Wishlists

To get a better look at data in the admin area, it's helpful to have filters. We
can filter wishlists by user or by product.

Update `app/views/store/wishlists/index.html.erb` by adding the following form:

```erb#1,3-7
<h1><%= pluralize @wishlists.count, "Wishlist" %></h1>

<%= form_with url: store_wishlists_path, method: :get do |form| %>
  <%= form.collection_select :user_id, User.all, :id, :full_name, selected: params[:user_id], include_blank: "All Users" %>
  <%= form.collection_select :product_id, Product.all, :id, :name, selected: params[:product_id], include_blank: "All Products" %>
  <%= form.submit "Filter" %>
<% end %>

<%= render @wishlists %>
```

We've updated the header to show the total number of wishlists, which makes it
easier to see how many results match when a filter is applied. When you submit
the form, Rails adds your selected filters to the URL as query params. The form
then reads those values when loading the page to automatically re-select the
same options in the dropdowns, so your choices stay visible after submitting.
Since the form submits to the index action, so it can display either all
wishlists or just the filtered results.

To make this work, we need to apply these filters in our SQL query with
Active Record. Update the controller to include these filters:

```ruby#4-5
class Store::WishlistsController < Store::BaseController
  def index
    @wishlists = Wishlist.includes(:user)
    @wishlists = @wishlists.where(user_id: params[:user_id]) if params[:user_id].present?
    @wishlists = @wishlists.includes(:wishlist_products).where(wishlist_products: { product_id: params[:product_id] }) if params[:product_id].present?
  end

  def show
    @wishlist = Wishlist.find(params[:id])
  end
end
```

Active Record queries are _lazy evaluated_ which means SQL queries aren't executed
until you ask for the results. This allows our controller to build up the query
step-by-step and include filters if needed.

Once you have more wishlists in the system, you can use the filters to view
wishlists by a specific user, product, or a combination of both.

### Refactoring Filters

Our controller has gotten a bit messy by introducing these filters. Let's move
our logic out of the controller by extracting a method on the `Wishlist` model.

```ruby#3
class Store::WishlistsController < Store::BaseController
  def index
    @wishlists = Wishlist.includes(:user).filter_by(params)
  end

  def show
    @wishlist = Wishlist.find(params[:id])
  end
end
```

We'll implement `filter_by` in the `Wishlist` model by defining a class method.

```ruby#8-13
class Wishlist < ApplicationRecord
  belongs_to :user
  has_many :wishlist_products, dependent: :destroy
  has_many :products, through: :wishlist_products

  to_param :name

  def self.filter_by(params)
    results = all
    results = results.where(user_id: params[:user_id]) if params[:user_id].present?
    results = results.includes(:wishlist_products).where(wishlist_products: {product_id: params[:product_id]}) if params[:product_id].present?
    results
  end
end
```

`filter_by` is almost the same as what we had in the controller, but we start by
calling
[`all`](https://api.rubyonrails.org/classes/ActiveRecord/Scoping/Named/ClassMethods.html#method-i-all)
which returns an `ActiveRecord::Relation` for all the records including any
conditions we may have already applied. Then we apply the filters and return the
results.

Refactoring like this means the controller becomes cleaner, while the filtering logic now lives in the model where it belongs, alongside other database-related logic. This follows the **Fat Model, Skinny Controller** principle, a best practice in Rails.

## Adding Subscribers To Admin

While we're here, we should also add the ability to view and filter subscribers in the
admin too. This is helpful to know how many people are waiting for a product to
go back in stock.

### Subscriber Views

First, we'll add the subscribers route to the `store` namespace:

```ruby#6
  # Admins Only
  namespace :store do
    resources :products
    resources :users
    resources :wishlists
    resources :subscribers

    root to: redirect("/store/products")
  end
```

Then, let's create the controller at
`app/controllers/store/subscribers_controller.rb`:

```ruby
class Store::SubscribersController < Store::BaseController
  before_action :set_subscriber, except: [ :index ]

  def index
    @subscribers = Subscriber.includes(:product).filter_by(params)
  end

  def show
  end

  def destroy
    @subscriber.destroy
    redirect_to store_subscribers_path, notice: "Subscriber has been removed.", status: :see_other
  end

  private
    def set_subscriber
      @subscriber = Subscriber.find(params[:id])
    end
end
```

We've only implemented `index`, `show`, and `destroy` actions here. Subscribers
will only be created when a user enters their email address. If someone contacts
support asking to unsubscribe them, we want to be able to remove them easily.

Since this is the admin area, we will want to add filters to subscribers too.

In `app/models/subscriber.rb`, let's add the `filter_by` class method:

```ruby
class Subscriber < ApplicationRecord
  belongs_to :product
  generates_token_for :unsubscribe

  def self.filter_by(params)
    results = all
    results = results.where(product_id: params[:product_id]) if params[:product_id].present?
    results
  end
end
```

Let's create the index view next at
`app/views/store/subscribers/index.html.erb`:

```erb
<h1><%= pluralize @subscribers.count, "Subscriber" %></h1>

<%= form_with url: store_subscribers_path, method: :get do |form| %>
  <%= form.collection_select :product_id, Product.all, :id, :name, selected: params[:product_id], include_blank: "All Products" %>
  <%= form.submit "Filter" %>
<% end %>

<%= render @subscribers %>
```

Then create `app/views/store/subscribers/_subscriber.html.erb` for displaying
each subscriber:

```erb
<div>
  <%= link_to subscriber.email, store_subscriber_path(subscriber) %> subscribed to <%= link_to subscriber.product.name, store_product_path(subscriber.product) %> on <%= l subscriber.created_at, format: :long %>
</div>
```

Next, create `app/views/store/subscribers/show.html.erb` to view an individual
subscriber:

```erb
<h1><%= @subscriber.email %></h1>
<p>Subscribed to <%= link_to @subscriber.product.name, store_product_path(@subscriber.product) %> on <%= l @subscriber.created_at, format: :long %></p>

<%= button_to "Remove", store_subscriber_path(@subscriber), method: :delete, data: { turbo_confirm: "Are you sure?" } %>
```

Finally, add the link to the sidebar layout:

```erb#14
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

Now you can view, filter, and remove subscribers in the store's admin area. Try
it out!

## Adding Links To Products

Now that we've added filters, we can add links to the Product show page for
viewing wishlists and subscribers for a specific product.

Open `app/views/store/products/show.html.erb` and add the links:

```erb#18-21
<p><%= link_to "Back", store_products_path %></p>

<section class="product">
  <%= image_tag @product.featured_image if @product.featured_image.attached? %>

  <section class="product-info">
    <% cache @product do %>
      <h1><%= @product.name %></h1>
      <%= @product.description %>
    <% end %>

    <%= link_to "View in Storefront", @product %>
    <%= link_to "Edit", edit_store_product_path(@product) %>
    <%= button_to "Delete", [ :store, @product ], method: :delete, data: { turbo_confirm: "Are you sure?" } %>
  </section>
</section>

<section>
  <%= link_to pluralize(@product.wishlists_count, "wishlist"), store_wishlists_path(product_id: @product) %>
  <%= link_to pluralize(@product.subscribers.count, "subscriber"), store_subscribers_path(product_id: @product) %>
</section>
```

## Testing Wishlists

Let's write some tests for the functionality we just built.

### Adding Fixtures

First, we need to update the fixtures in `test/fixtures/wishlist_products.yml`
so they refer to the product fixtures we have defined:

```yaml
one:
  product: tshirt
  wishlist: one

two:
  product: tshirt
  wishlist: two
```

Let's also add another `Product` fixture in `test/fixtures/products.yml` to test
with:

```yaml#5-7
tshirt:
  name: T-Shirt
  inventory_count: 15

shoes:
  name: shoes
  inventory_count: 0
```

### Testing `filter_by`

The `Wishlist` model's `filter_by` method is important to ensure it's filtering
records correctly.

Open `test/models/wishlist_test.rb` and add this test to start:

```ruby
require "test_helper"

class WishlistTest < ActiveSupport::TestCase
  test "filter_by with no filters" do
    assert_equal Wishlist.all, Wishlist.filter_by({})
  end
end
```

This test ensures that `filter_by` returns all records when no filters are
applied.

Then run the test:

```bash
$ bin/rails test test/models/wishlist_test.rb
Running 1 tests in a single process (parallelization threshold is 50)
Run options: --seed 64578

# Running:

.

Finished in 0.290295s, 3.4448 runs/s, 3.4448 assertions/s.
1 runs, 1 assertions, 0 failures, 0 errors, 0 skips
```

Great! Next, we need to test the `user_id` filter. Let's add another test:

```ruby#8-12
require "test_helper"

class WishlistTest < ActiveSupport::TestCase
  test "filter_by with no filters" do
    assert_equal Wishlist.all, Wishlist.filter_by({})
  end

  test "filter_by with user_id" do
    wishlists = Wishlist.filter_by(user_id: users(:one).id)
    assert_includes wishlists, wishlists(:one)
    assert_not_includes wishlists, wishlists(:two)
  end
end
```

This test runs the query and asserts the wishlist for the user is returned but
not wishlists for another user.

Let's run the test file again:

```bash
$ bin/rails test test/models/wishlist_test.rb
Running 2 tests in a single process (parallelization threshold is 50)
Run options: --seed 48224

# Running:

..

Finished in 0.292714s, 6.8326 runs/s, 17.0815 assertions/s.
2 runs, 5 assertions, 0 failures, 0 errors, 0 skips
```

Perfect! Both tests are passing.

Finally, let's add a test for wishlists with a specific product.

For this test, we need to add a unique product to one of our wishlists so it can
be filtered.

Open `test/fixtures/wishlist_products.yml` and add the following:

```yaml#9-11
one:
  product: tshirt
  wishlist: one

two:
  product: tshirt
  wishlist: two

three:
  product: shoes
  wishlist: two
```

Then add the following test to `test/models/wishlist_test.rb`:

```ruby
require "test_helper"

class WishlistTest < ActiveSupport::TestCase
  test "filter_by with no filters" do
    assert_equal Wishlist.all, Wishlist.filter_by({})
  end

  test "filter_by with user_id" do
    wishlists = Wishlist.filter_by(user_id: users(:one).id)
    assert_includes wishlists, wishlists(:one)
    assert_not_includes wishlists, wishlists(:two)
  end

  test "filter_by with product_id" do
    wishlists = Wishlist.filter_by(product_id: products(:shoes).id)
    assert_includes wishlists, wishlists(:two)
    assert_not_includes wishlists, wishlists(:one)
  end
end
```

This test filters by a specific product and ensures the correct wishlist is
returned and wishlists without that product are not.

Let's run this test file again to ensure they are all passing:

```ruby
bin/rails test test/models/wishlist_test.rb
Running 3 tests in a single process (parallelization threshold is 50)
Run options: --seed 27430

# Running:

...

Finished in 0.320054s, 9.3734 runs/s, 28.1203 assertions/s.
3 runs, 9 assertions, 0 failures, 0 errors, 0 skips
```

### Testing Wishlist CRUD

Let's walk through writing some integration tests for wishlists.

Create `test/integration/wishlists_test.rb` and add a test for creating a
wishlist.

```ruby
require "test_helper"

class WishlistsTest < ActionDispatch::IntegrationTest
  test "create a wishlist" do
    user = users(:one)
    sign_in_as user
    assert_difference "user.wishlists.count" do
      post wishlists_path, params: { wishlist: { name: "Example" } }
      assert_response :redirect
    end
  end
end
```

This test logs in as a user and makes a POST request to create a wishlist. It
checks the user's wishlists count before and after to ensure a new record was
created. It also confirms the user is redirected instead of re-rendering the
form with errors.

Let's run this test and make sure it passes.

```bash
$ bin/rails test test/integration/wishlists_test.rb
Running 1 tests in a single process (parallelization threshold is 50)
Run options: --seed 40232

# Running:

.

Finished in 0.603018s, 1.6583 runs/s, 4.9750 assertions/s.
1 runs, 3 assertions, 0 failures, 0 errors, 0 skips
```

Next, let's add a test for deleting a wishlist.

```ruby
test "delete a wishlist" do
  user = users(:one)
  sign_in_as user
  assert_difference "user.wishlists.count", -1 do
    delete wishlist_path(user.wishlists.first)
    assert_redirected_to wishlists_path
  end
end
```

This test is similar to creating wishlists, but it asserts that there is one
less wishlist after making the DELETE request.

Next, we should test viewing wishlists, starting with a user viewing their own
wishlist.

```ruby
test "view a wishlist" do
  user = users(:one)
  wishlist = user.wishlists.first
  sign_in_as user
  get wishlist_path(wishlist)
  assert_response :success
  assert_select "h1", text: wishlist.name
end
```

A user should also be able to view other user's wishlists, so let's test that:

```ruby
test "view a wishlist as another user" do
  wishlist = wishlists(:two)
  sign_in_as users(:one)
  get wishlist_path(wishlist)
  assert_response :success
  assert_select "h1", text: wishlist.name
end
```

And guests should be able to view wishlists too:

```ruby
test "view a wishlist as a guest" do
  wishlist = wishlists(:one)
  get wishlist_path(wishlist)
  assert_response :success
  assert_select "h1", text: wishlist.name
end
```

Let's run these tests and make sure they all pass:

```bash
$ bin/rails test test/integration/wishlists_test.rb
Running 5 tests in a single process (parallelization threshold is 50)
Run options: --seed 43675

# Running:

.....

Finished in 0.645956s, 7.7405 runs/s, 13.9328 assertions/s.
5 runs, 9 assertions, 0 failures, 0 errors, 0 skips
```

Excellent!

### Testing Wishlist Products

Next, let's test products in wishlists. The best place to start is probably
adding a product to a wishlist.

Add the following test to `test/integration/wishlists_test.rb`:

```ruby
test "add product to a specific wishlist" do
  sign_in_as users(:one)
  wishlist = wishlists(:one)
  assert_difference "WishlistProduct.count" do
    post product_wishlist_path(products(:shoes)), params: { wishlist_id: wishlist.id }
    assert_redirected_to wishlist
  end
end
```

This test asserts that a new `WishlistProduct` record is created when we send a
POST request that simulates submitting the "Add to wishlist" form with a
selected wishlist.

Next, let's test the case where a user has no wishlists.

```ruby
test "add product when no wishlists" do
  user = users(:one)
  sign_in_as user
  user.wishlists.destroy_all
  assert_difference "Wishlist.count" do
    assert_difference "WishlistProduct.count" do
      post product_wishlist_path(products(:shoes))
    end
  end
end
```

In this test, we delete all the user's wishlists to remove any wishlists that
may be present from fixtures. In addition to asserting a new `WishlistProduct`
was created, we also make sure a new `Wishlist` was created this time.

We should also test that we can't add products to another user's wishlist. Add
the following test.

```ruby
test "cannot add product to another user's wishlist" do
  sign_in_as users(:one)
  assert_no_difference "WishlistProduct.count" do
    post product_wishlist_path(products(:shoes)), params: { wishlist_id: wishlists(:two).id }
    assert_response :not_found
  end
end
```

In this case, we sign in as one user and `POST` with the ID of a wishlist from
another user. To ensure this is working correctly, we assert that no new
`WishlistProduct` records were created and we also make sure the response was a
404 Not Found.

Now, let's test moving products between wishlists.

```ruby
test "move product to another wishlist" do
  user = users(:one)
  sign_in_as user
  wishlist = user.wishlists.first
  wishlist_product = wishlist.wishlist_products.first
  second_wishlist = user.wishlists.create!(name: "Second Wishlist")
  patch wishlist_wishlist_product_path(wishlist, wishlist_product), params: { new_wishlist_id: second_wishlist.id }
  assert_equal second_wishlist, wishlist_product.reload.wishlist
end
```

This test has a bit more setup than the others. It creates a second wishlist to
move the product to. Since this action updates the `wishlist_id` column of the
`WishlistProduct` record, we save it to a variable and assert that it changes
after the request completes.

We have to call `wishlist_product.reload` since the copy of the record in memory
is unaware of changes that happened during the request. This reloads the record
from the database so we can see the new values.

Next, let's test moving a product to a wishlist that already contains the
product. In this case, we should get an error message and the `WishlistProduct`
should have no changes.

```ruby
  test "cannot move product to a wishlist that already contains product" do
    user = users(:one)
    sign_in_as user
    wishlist = user.wishlists.first
    wishlist_product = wishlist.wishlist_products.first
    second_wishlist = user.wishlists.create!(name: "Second")
    second_wishlist.wishlist_products.create(product_id: wishlist_product.product_id)
    patch wishlist_wishlist_product_path(wishlist, wishlist_product), params: { new_wishlist_id: second_wishlist.id }
    assert_equal "T-Shirt is already on Second.", flash[:alert]
    assert_equal wishlist, wishlist_product.reload.wishlist
  end
```

This test uses an assertion against `flash[:alert]` to check for the error
message. It also reloads `wishlist_product` to assert that the wishlist has not
changed.

Finally, we should add a test to ensure a user cannot move a product to another
user's wishlist.

```ruby
  test "cannot move product to another user's wishlist" do
    user = users(:one)
    sign_in_as user
    wishlist = user.wishlists.first
    wishlist_product = wishlist.wishlist_products.first
    patch wishlist_wishlist_product_path(wishlist, wishlist_product), params: { new_wishlist_id: wishlists(:two).id }
    assert_response :not_found
    assert_equal wishlist, wishlist_product.reload.wishlist
  end
```

In this case, we assert that the response was a 404 Not Found which shows that
we safely scoped the `new_wishlist_id` to the current user.

It also asserts that the wishlist did not change, just like the previous test.

Alright, let's run this full set of tests to double check they all pass.

```bash
$ bin/rails test test/integration/wishlists_test.rb
Running 11 tests in a single process (parallelization threshold is 50)
Run options: --seed 65170

# Running:

...........

Finished in 1.084135s, 10.1463 runs/s, 23.0599 assertions/s.
11 runs, 25 assertions, 0 failures, 0 errors, 0 skips
```

Fantastic! Our tests are all passing.

## Deploying To Production

Since we previously setup Kamal in the
[Getting Started Guide](getting_started.html), we just need to push our code
changes to our Git repository and run:

```bash
$ bin/kamal deploy
```

## What's Next

Your e-commerce store now has Wishlists and an improved admin area with
filtering of Wishlists and Subscribers.

Here are a few ideas to build on to this:

- Add product reviews
- Write more tests
- Finish translating the app into another language
- Add a carousel for product images
- Improve the design with CSS
- Add payments to buy products

[Return to all tutorials](https://rubyonrails.org/docs/tutorials)
