**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Sign Up and Settings
====================

This guide covers adding Sign Up and Settings to the store e-commerce
application in the [Getting Started Guide](getting_started.html). We will use
the final code from that guide as a starting place.

After reading this guide, you will know how to:

* Add user Sign Up
* Rate limit controller actions
* Create a nested layout
* Separate controllers by role (users and admins)
* Write tests for users with different roles

--------------------------------------------------------------------------------

Introduction
------------

One of the most common features to add to any application is a sign up process
for registering new users. The e-commerce application we've built so far only
has authentication and users must be created in the Rails console or a script.

This feature is required before we can add other features. For example, to let
users create wishlists, they will need to be able to sign up first before they
can create a wishlist associated with their account.

Let's get started!

Adding Sign Up
--------------

We've already used the
[Rails authentication generator in the Getting Started guide](/getting_started.html#adding-authentication)
to allow users to login to their accounts. The generator created a `User` model
with `email_address:string` and `password_digest:string` columns in the
database. It also added `has_secure_password` to the `User` model which handles
passwords and confirmations. This takes care of most of what we need to add sign
up to our application.

### Adding Names To Users

It's also a good idea to collect the user's name at sign up. This allows us to
personalize their experience and address them directly in the application. Let's
start by adding `first_name` and `last_name` columns to the database.

In the terminal, create a migration with these columns:

```bash
$ bin/rails g migration AddNamesToUsers first_name:string last_name:string
```

Then migrate the database:

```bash
$ bin/rails db:migrate
```

Let's also add a method to combine `first_name` and `last_name`, so that we can
display the user's full name.

Open `app/models/user.rb` and add the following:

```ruby#7-11
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :first_name, :last_name, presence: true

  def full_name
    "#{first_name} #{last_name}"
  end
end
```

TIP: `has_secure_password` only validates the presence of the password. Consider
adding more validations for password minimum length or complexity to improve
security.

Next, let's add sign up so we can register new users.

### Sign Up Routes & Controller

Now that our database has all the necessary columns to register new users, the
next step is to create a route for sign up and its matching controller.

In `config/routes.rb`, let's add a resource for sign up:

```ruby#3
resource :session
resources :passwords, param: :token
resource :sign_up
```

We're using a singular resource here because we want a singular route for
`/sign_up`.

This route directs requests to `app/controllers/sign_ups_controller.rb` so let's
create that controller file now.

```ruby
class SignUpsController < ApplicationController
  def show
    @user = User.new
  end
end
```

We're using the `show` action to create a new `User` instance, which will be
used to display the sign up form.

Let's create the form next. Create `app/views/sign_ups/show.html.erb` with the
following code:

```erb
<h1>Sign Up</h1>

<%= form_with model: @user, url: sign_up_path do |form| %>
  <% if form.object.errors.any? %>
    <div>Error: <%= form.object.errors.full_messages.first %></div>
  <% end %>

  <div>
    <%= form.label :first_name %>
    <%= form.text_field :first_name, required: true, autofocus: true, autocomplete: "given-name" %>
  </div>

  <div>
    <%= form.label :last_name %>
    <%= form.text_field :last_name, required: true, autocomplete: "family-name" %>
  </div>

  <div>
    <%= form.label :email_address %>
    <%= form.email_field :email_address, required: true, autocomplete: "email" %>
  </div>

  <div>
    <%= form.label :password %>
    <%= form.password_field :password, required: true, autocomplete: "new-password" %>
  </div>

  <div>
    <%= form.label :password_confirmation %>
    <%= form.password_field :password_confirmation, required: true, autocomplete: "new-password" %>
  </div>

  <div>
    <%= form.submit "Sign up" %>
  </div>
<% end %>
```

This form collects the user's name, email, and password. We're using the
`autocomplete` attribute to help the browser suggest the values for these fields
based on the user's saved information.

You'll also notice we set `url: sign_up_path` in the form alongside
`model: @user`. Without this `url:` argument, `form_with` would see we have a
`User` and send the form to `/users` by default. Since we want the form to
submit to `/sign_up`, we set the `url:` to override the default route.

Back in `app/controllers/sign_ups_controller.rb` we can handle the form
submission by adding the `create` action.

```ruby#6-19
class SignUpsController < ApplicationController
  def show
    @user = User.new
  end

  def create
    @user = User.new(sign_up_params)
    if @user.save
      start_new_session_for(@user)
      redirect_to root_path
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def sign_up_params
      params.expect(user: [ :first_name, :last_name, :email_address, :password, :password_confirmation ])
    end
end
```

The `create` action assigns parameters and attempts to save the user to the
database. If successful, it logs the user in and redirects to `root_path`,
otherwise it re-renders the form with errors.

Visit https://localhost:3000/sign_up to try it out.

### Requiring Unauthenticated Access

Authenticated users can still access `SignUpsController` and create another
account while they're logged in which is confusing.

Let's fix this by adding a helper to the `Authentication` module in
`app/controllers/concerns/authentication.rb`.

```ruby#14-17
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end

    def unauthenticated_access_only(**options)
      allow_unauthenticated_access **options
      before_action -> { redirect_to root_path if authenticated? }, **options
    end

    # ...
```

The `unauthenticated_access_only` class method can be used in any controller
where we want to restrict actions to unauthenticated users only.

We can then use this method at the top of `SignUpsController`.

```ruby#2
class SignUpsController < ApplicationController
  unauthenticated_access_only

  # ...
end
```

### Rate Limiting Sign Up

Our application will be accessible on the internet so we're bound to have
malicious bots and users trying to spam our application. We can add rate
limiting to sign up to slow down anyone submitting too many requests.

Rails makes this easy with the
[`rate_limit`](https://api.rubyonrails.org/classes/ActionController/RateLimiting/ClassMethods.html)
method in controllers.

```ruby#3
class SignUpsController < ApplicationController
  unauthenticated_access_only
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to sign_up_path, alert: "Try again later." }

  # ...
end
```

This will block any form submissions that happen more than 10 times within 3
minutes.

Editing Passwords
-----------------

Now that users can login, let's create all the usual places that users would
expect to update their profile, password, email address, and other settings.

### Using Namespaces

The Rails authentication generator already created a controller at
`app/controllers/passwords_controller.rb` for password resets. This means we
need to use a different controller for editing passwords of authenticated users.

To prevent conflicts, we can use a feature called **namespaces**. A namespace
organizes routes, controllers, and views into folders and helps prevent
conflicts like our two passwords controllers.

We'll create a namespace called "Settings" to separate out the user and store
settings from the rest of our application.

In `config/routes.rb` we can add the Settings namespace along with a resource
for editing passwords:

```ruby
namespace :settings do
  resource :password, only: [ :show, :update ]
end
```

This will generate a route for `/settings/password` for editing the current
user's password which is separate from the password resets routes at
`/password`.

### Adding the Namespaced Passwords Controller & View

Namespaces also move controllers into a matching module in Ruby. This controller
will be in a `settings` folder to match the namespace.

Let's create the folder and controller at
`app/controllers/settings/passwords_controller.rb` and start with the `show`
action.

```ruby
class Settings::PasswordsController < ApplicationController
  def show
  end
end
```

Views also move to a `settings` folder so let's create the folder and view at
`app/views/settings/passwords/show.html.erb` for this action.

```erb
<h1>Password</h1>

<%= form_with model: Current.user, url: settings_password_path do |form| %>
  <% if form.object.errors.any? %>
    <div><%= form.object.errors.full_messages.first %></div>
  <% end %>

  <div>
    <%= form.label :password_challenge %>
    <%= form.password_field :password_challenge, required: true, autocomplete: "current-password" %>
  </div>

  <div>
    <%= form.label :password %>
    <%= form.password_field :password, required: true, autocomplete: "new-password" %>
  </div>

  <div>
    <%= form.label :password_confirmation %>
    <%= form.password_field :password_confirmation, required: true, autocomplete: "new-password" %>
  </div>

  <div>
    <%= form.submit "Update password" %>
  </div>
<% end %>
```

We've set the `url:` argument to ensure the form submits to our namespaced route
and is processed by the `Settings::PasswordsController`.

Passing `model: Current.user` also tells `form_with` to submit a `PATCH` request
to process the form with the `update` action.

TIP: `Current.user` comes from
[CurrentAttributes](https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html)
which is a per-request attribute which resets automatically before and after
each request. The Rails authentication generator uses this to keep track of the
logged in User.

### Safely Updating Passwords

Let's add that `update` action to the controller now.

```ruby#5-16
class Settings::PasswordsController < ApplicationController
  def show
  end

  def update
    if Current.user.update(password_params)
      redirect_to settings_profile_path, status: :see_other, notice: "Your password has been updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def password_params
      params.expect(user: [ :password, :password_confirmation, :password_challenge ]).with_defaults(password_challenge: "")
    end
end
```

For security, we need to ensure that the user is the only one who can update
their password. The `has_secure_password` method in our `User` model provides
this attribute. If `password_challenge` is present, it will validate the
password challenge against the user's current password in the database to
confirm it matches.

A malicious user could try deleting the `password_challenge` field in the
browser to bypass this validation. To prevent this and ensure the validation
always runs, we use `.with_defaults(password_challenge: "")` to set a default
value even if the `password_challenge` parameter is missing.

You can now visit http://localhost:3000/settings/password to update your
password.

### Renaming The Password Challenge Attribute

While `password_challenge` is a good name for our code, users are used to seeing
"Current password" for this form field. We can rename this with locales in Rails
to change how this attribute is displayed on the frontend.

Add the following to `config/locales/en.yml`:

```yaml#7-10
en:
  hello: "Hello world"
  products:
    index:
      title: "Products"

  activerecord:
    attributes:
      user:
        password_challenge: "Current password"
```

To learn more, check out the
[I18n Guide](https://guides.rubyonrails.org/i18n.html#translations-for-active-record-models)

Editing User Profiles
---------------------

Next, let's add a page so users can edit their profile, like updating their
first and last name.

### Profile Routes & Controller

In `config/routes.rb`, add a profile resource under the settings namespace. We
can also add a root to the namespace to handle any visits to `/settings` and
redirect them to profile settings.

```ruby#3,5
namespace :settings do
  resource :password, only: [ :show, :update ]
  resource :profile, only: [ :show, :update ]

  root to: redirect("/settings/profile")
end
```

Let's create our controller for editing profiles at
`app/controllers/settings/profiles_controller.rb`.

```ruby
class Settings::ProfilesController < ApplicationController
  def show
  end

  def update
    if Current.user.update(profile_params)
      redirect_to settings_profile_path, status: :see_other, notice: "Your profile was updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def profile_params
      params.expect(user: [ :first_name, :last_name ])
    end
end
```

This is very similar to the passwords controller but only allows updating the
user's profile details like first and last name.

Then create `app/views/settings/profiles/show.html.erb` to show the edit profile
form.

```erb
<h1>Profile</h1>

<%= form_with model: Current.user, url: settings_profile_path do |form| %>
  <% if form.object.errors.any? %>
    <div>Error: <%= form.object.errors.full_messages.first %></div>
  <% end %>

  <div>
    <%= form.label :first_name %>
    <%= form.text_field :first_name, required: true, autocomplete: "given-name" %>
  </div>

  <div>
    <%= form.label :last_name %>
    <%= form.text_field :last_name, required: true, autocomplete: "family-name" %>
  </div>

  <div>
    <%= form.submit "Update profile" %>
  </div>
<% end %>
```

You can now visit http://localhost:3000/settings/profile to update your name.

### Updating Navigation

Let's update the navigation to include a link to Settings next to the Log out
button.

Open `app/views/layouts/application.html.erb` and update the navbar. We'll also
add a div for any alert messages from our controllers while we're here.

```erb#9,13-19
<!DOCTYPE html>
<html>
  <head>
    <%# ... %>
  </head>

  <body>
    <div class="notice"><%= notice %></div>
    <div class="alert"><%= alert %></div>

    <nav class="navbar">
      <%= link_to "Home", root_path %>
      <% if authenticated? %>
        <%= link_to "Settings", settings_root_path %>
        <%= button_to "Log out", session_path, method: :delete %>
      <% else %>
        <%= link_to "Sign Up", sign_up_path %>
        <%= link_to "Login", new_session_path %>
      <% end %>
    </nav>
```

You'll now see a Settings link in the navbar when authenticated.

### Settings Layout

While we're here, let's add a new layout for Settings so we can organize them in
a sidebar. To do this, we're going to use a
[Nested Layout](layouts_and_rendering.html#using-nested-layouts).

A nested layout allows you add HTML (like a sidebar) while still rendering the
application layout. This means we don't have to duplicate our head tags or
navigation in our Settings layout.

Let's create `app/views/layouts/settings.html.erb` and add the following:

```erb
<%= content_for :content do %>
  <section class="settings">
    <nav>
      <h4>Account Settings</h4>
      <%= link_to "Profile", settings_profile_path %>
      <%= link_to "Password", settings_password_path %>
    </nav>

    <div>
      <%= yield %>
    </div>
  </section>
<% end %>

<%= render template: "layouts/application" %>
```

In the settings layout, we're providing HTML for the sidebar and telling Rails
to render the application layout as the parent.

We need to modify the application layout to render the content from the nested
layout using `yield(:content)`.

```erb#11,23
<!DOCTYPE html>
<html>
  <head>
    <%# ... %>
  </head>

  <body>
    <div class="notice"><%= notice %></div>
    <div class="alert"><%= alert %></div>

    <nav class="navbar">
      <%= link_to "Home", root_path %>
      <% if authenticated? %>
        <%= link_to "Settings", settings_root_path %>
        <%= button_to "Log out", session_path, method: :delete %>
      <% else %>
        <%= link_to "Sign Up", sign_up_path %>
        <%= link_to "Login", new_session_path %>
      <% end %>
    </nav>

    <main>
      <%= content_for?(:content) ? yield(:content) : yield %>
    </main>
  </body>
</html
```

This allows the application controller to be used normally with `yield` or it
can be a parent layout if `content_for(:content)` is used in a nested layout.

We now have two separate `<nav>` tags, so we need to update our existing CSS
selectors to avoid conflicts.

To do this, add the `.navbar` class to these selectors in
`app/assets/stylesheets/application.css`.

```css#1,11
nav.navbar {
  justify-content: flex-end;
  display: flex;
  font-size: 0.875em;
  gap: 0.5rem;
  max-width: 1024px;
  margin: 0 auto;
  padding: 1rem;
}

nav.navbar a {
  display: inline-block;
}
```

Then add some CSS to display the Settings nav as a sidebar.

```css
section.settings {
  display: flex;
  gap: 1rem;
}

section.settings nav {
  width: 200px;
}

section.settings nav a {
  display: block;
}
```

To use this new layout, we can tell the controller we want to use a specific
layout. We can add `layout "settings"` to any controller to change the layout
that is rendered.

Since we will have many controllers that use this layout, we can create a base
class to define shared configuration and use inheritance to use them.

Add `app/controllers/settings/base_controller.rb` and add the following:

```ruby
class Settings::BaseController < ApplicationController
  layout "settings"
end
```

Then update `app/controllers/settings/passwords_controller.rb` to inherit from
this controller.

```ruby
class Settings::PasswordsController < Settings::BaseController
```

And update `app/controllers/settings/profiles_controller.rb` to inherit from it
too.

```ruby
class Settings::ProfilesController < Settings::BaseController
```

Deleting Accounts
-----------------

Next, let's add the ability to delete your account. We'll start by adding
another namespaced route for account to `config/routes.rb`.

```ruby#4
namespace :settings do
  resource :password, only: [ :show, :update ]
  resource :profile, only: [ :show, :update ]
  resource :user, only: [ :show, :destroy ]

  root to: redirect("/settings/profile")
end
```

To handle these new routes, create
`app/controllers/settings/users_controller.rb` and add the following:

```ruby
class Settings::UsersController < Settings::BaseController
  def show
  end

  def destroy
    terminate_session
    Current.user.destroy
    redirect_to root_path, notice: "Your account has been deleted."
  end
end
```

The controller for deleting accounts is pretty straightforward. We have a `show`
action to display the page and a `destroy` action to logout and delete the user.
It also inherits from `Settings::BaseController` so it will use the settings
layout like the others.

Now let's add the view at `app/views/settings/users/show.html.erb` with the
following:

```erb
<h1>Account</h1>

<%= button_to "Delete my account", settings_user_path, method: :delete, data: { turbo_confirm: "Are you sure? This cannot be undone." } %>
```

And finally, we'll add a link to Account in the setting layout's sidebar.

```erb#7
<%= content_for :content do %>
  <section class="settings">
    <nav>
      <h4>Account Settings</h4>
      <%= link_to "Profile", settings_profile_path %>
      <%= link_to "Password", settings_password_path %>
      <%= link_to "Account", settings_user_path %>
    </nav>

    <div>
      <%= yield %>
    </div>
  </section>
<% end %>

<%= render template: "layouts/application" %>
```

That's it! You can now delete your account.

Updating Email Addresses
------------------------

Occasionally, users need to change the email address on their account. To do
this safely, we need to store the new email address and send an email to confirm
the change.

### Adding Unconfirmed Email To Users

We'll start by adding a new field to the users table in our database. This will
store the new email address while we're waiting for confirmation.

```bash
$ bin/rails g migration AddUnconfirmedEmailToUsers unconfirmed_email:string
```

Then migrate the database.

```bash
$ bin/rails db:migrate
```


### Email Routes & Controller

Next we can add an email route under the `:settings` namespace in
`config/routes.rb`.

```ruby#2
namespace :settings do
  resource :email, only: [ :show, :update ]
  resource :password, only: [ :show, :update ]
  resource :profile, only: [ :show, :update ]
  resource :user, only: [ :show, :destroy ]

  root to: redirect("/settings/profile")
end
```

Then we'll create `app/controllers/settings/emails_controller.rb` to display
this.

```ruby
class Settings::EmailsController < Settings::BaseController
  def show
  end
end
```

And finally, we'll create our view at `app/views/settings/emails/show.html.erb`:

```erb
<h1>Change Email</h1>

<%= form_with model: Current.user, url: settings_email_path do |form| %>
  <% if form.object.errors.any? %>
    <div>Error: <%= form.object.errors.full_messages.first %></div>
  <% end %>

  <div>
    <%= form.label :unconfirmed_email, "New email address" %>
    <%= form.email_field :unconfirmed_email, required: true %>
  </div>

  <div>
    <%= form.label :password_challenge %>
    <%= form.password_field :password_challenge, required: true, autocomplete: "current-password" %>
  </div>

  <div>
    <%= form.submit "Update email address" %>
  </div>
<% end %>
```

To keep things secure, we need to ask for the new email address and validate
user's current password to ensure only the owner of the account can change the
email.

In our controller, we will validate the current password and save the new email
address before sending an email to confirm the new email address.

```ruby#5-17
class Settings::EmailsController < Settings::BaseController
  def show
  end

  def update
    if Current.user.update(email_params)
      UserMailer.with(user: Current.user).email_confirmation.deliver_later
      redirect_to settings_email_path, status: :see_other, notice: "We've sent a verification email to #{Current.user.unconfirmed_email}."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def email_params
      params.expect(user: [ :password_challenge, :unconfirmed_email ]).with_defaults(password_challenge: "")
    end
end
```

This uses the same `with_defaults(password_challenge: "")` as
`Settings::PasswordsController` to trigger the password challenge validation.

We haven't created the `UserMailer` yet, so let's do that next.

### New Email Confirmation

Let's use the mailer generator to create the `UserMailer` we referenced in
`Settings::EmailsController`:

```bash
$ bin/rails generate mailer User email_confirmation
      create  app/mailers/user_mailer.rb
      invoke  erb
      create    app/views/user_mailer
      create    app/views/user_mailer/email_confirmation.text.erb
      create    app/views/user_mailer/email_confirmation.html.erb
      invoke  test_unit
      create    test/mailers/user_mailer_test.rb
      create    test/mailers/previews/user_mailer_preview.rb
```

We'll need to generate a token to include in the email body. Open
`app/models/user.rb` and add the following:

```ruby#9-15
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :first_name, :last_name, presence: true

  generates_token_for :email_confirmation, expires_in: 7.days do
    unconfirmed_email
  end

  def confirm_email
    update(email_address: unconfirmed_email, unconfirmed_email: nil)
  end

  def full_name
    "#{first_name} #{last_name}"
  end
end
```

This adds a token generator we can use for email confirmations. The token
encodes the unconfirmed email, so it becomes invalid if the email changes or the
token expires.

Let's update `app/mailers/user_mailer.rb` to generate a new token for the email:

```ruby#6-9
class UserMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.user_mailer.email_confirmation.subject
  def email_confirmation
    @token = params[:user].generate_token_for(:email_confirmation)
    mail to: params[:user].unconfirmed_email
  end
end
```

We'll include the token in the HTML view at
`app/views/user_mailer/email_confirmation.html.erb`:

```erb
<h1>Verify your email address</h1>

<p><%= link_to "Confirm your email", email_confirmation_url(token: @token) %></p>
```

And `app/views/user_mailer/email_confirmation.text.erb`:

```erb
Confirm your email: <%= email_confirmation_url(token: @token) %>
```

### Email Confirmation Controller

The confirmation email includes a link to our Rails app to verify the email
change.

Let's add a route for this to `config/routes.rb`

```ruby
namespace :email do
  resources :confirmations, param: :token, only: [ :show ]
end
```

When a user clicks a link in their email, it will open a browser and make a GET
request to the app. This means we only need the `show` action for this
controller.

Next, add the following to `app/controllers/email/confirmations_controller.rb`

```ruby
class Email::ConfirmationsController < ApplicationController
  allow_unauthenticated_access

  def show
    user = User.find_by_token_for(:email_confirmation, params[:token])
    if user&.confirm_email
      flash[:notice] = "Your email has been confirmed."
    else
      flash[:alert] = "Invalid token."
    end
    redirect_to root_path
  end
end
```

We want to confirm the email address whether the user is authenticated or not,
so this controller allows unauthenticated access. We use the `find_by_token_for`
method to validate the token and look up the matching `User` record. If
successful, we call the `confirm_email` method to update the user's email and
reset `unconfirmed_email` to `nil`. If the token isn't valid, the `user`
variable will be `nil`, and we will display an alert message.

Finally, let's add a link to Email in the settings layout sidebar:

```erb#6
<%= content_for :content do %>
  <section class="settings">
    <nav>
      <h4>Account Settings</h4>
      <%= link_to "Profile", settings_profile_path %>
      <%= link_to "Email", settings_email_path %>
      <%= link_to "Password", settings_password_path %>
      <%= link_to "Account", settings_user_path %>
    </nav>

    <div>
      <%= yield %>
    </div>
  </section>
<% end %>

<%= render template: "layouts/application" %>
```

Test out this process by navigating to https://localhost:3000/settings/email and
updating your email address. Watch the Rails server logs for the email contents
and open the confirm link in your browser to update the email in the database.

Separating Admins & Users
-------------------------

Now that anyone can sign up for an account on our store, we need to
differentiate between regular users and admins.

### Adding An Admin Flag

We'll start by adding a column to the User model.

```bash
$ bin/rails g migration AddAdminToUsers admin:boolean
```

Then migrate the database.

```bash
$ bin/rails db:migrate
```

A `User` with `admin` set to `true` should be able to add and remove products
and access other administrative areas of the store.

### Readonly Attributes

We need to be very careful that `admin` is not editable by any malicious users.
This is easy enough by keeping the `:admin` attribute out of any permitted
parameters list.

Optionally, we can mark the admin attribute as readonly for added security. This
will tell Rails to raise an error anytime the admin attribute is changed. It can
still be set when creating a record, but provides an additional layer of
security against unauthorized changes. You may want to skip this if you'll be
changing the admin flag for users often but in our e-commerce store, it's a
useful safeguard.

We can add `attr_readonly` in our model to protect the attribute from updates.

```ruby#5
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  attr_readonly :admin

  # ...
```

When `admin` is read-only, we have to directly update this in the database
instead of using Active Record.

Rails has a command called `dbconsole` that will open a database console where
we can directly interact with the database using SQL.

```bash
$ bin/rails dbconsole
SQLite version 3.43.2 2023-10-10 13:08:14
Enter ".help" for usage hints.
sqlite>
```

In the SQLite prompt, we can update the admin column for a record using an
`UPDATE` statement and using `WHERE` to filter to a single user ID.

```sql
UPDATE users SET admin=true WHERE users.id=1;
```

To close the SQLite prompt, enter the following command:

```
.quit
```

Viewing All Users
-----------------

As a store admin, we will want to view and manage users for customer support,
marketing and other use cases.

First, we'll need to add a route for users in a new `store` namespace in
`config/routes.rb`.

```ruby
# Admins Only
namespace :store do
  resources :users
end
```

### Adding Admin Only Access

The controller for users should be accessible to admins only. Before we create
that controller, let's create an `Authorization` module with a class method to
restrict access to admins only.

Create `app/controllers/concerns/authorization.rb` with the following code:

```ruby
module Authorization
  extend ActiveSupport::Concern

  class_methods do
    def admin_access_only(**options)
      before_action -> { redirect_to root_path, alert: "You aren't allowed to do that." unless authenticated? && Current.user.admin? }, **options
    end
  end
end
```

To use this module in our controllers, include it in
`app/controllers/application_controller.rb`

```ruby#3
class ApplicationController < ActionController::Base
  include Authentication
  include Authorization

  # ...
```

The `Authorization` module features can be used in any controller in our app.
This module provides a home for any additional helpers to manage access for
admins or other types of roles in the future.

### Users Controller & Views

First, create a base class for the `store` namespace at
`app/controllers/store/base_controller.rb`.

```ruby
class Store::BaseController < ApplicationController
  admin_access_only
  layout "settings"
end
```

This controller will restrict access to admins only using the
`admin_access_only` method we just created. It will also use the same settings
layout to display the sidebar.

Next, create `app/controllers/store/users_controller.rb` and add the following:

```ruby
class Store::UsersController < Store::BaseController
  before_action :set_user, only: %i[ show edit update destroy ]

  def index
    @users = User.all
  end

  def show
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to store_user_path(@user), status: :see_other, notice: "User has been updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
  end

  private
    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.expect(user: [ :first_name, :last_name, :email_address ])
    end
end
```

This gives admins the ability to read, update, and destroy users in the
database.

Next, let's create the index view at `app/views/store/users/index.html.erb`

```erb
<h1><%= pluralize @users.count, "user" %></h1>

<% @users.each do |user| %>
  <div>
    <%= link_to user.full_name, store_user_path(user) %>
  </div>
<% end %>
```

Then, the edit user view at `app/views/store/users/edit.html.erb`:

```erb
<h1>Edit User</h1>
<%= render "form", user: @user %>
```

And the form partial at `app/views/store/users/_form.html.erb`:

```erb
<%= form_with model: [ :store, user ] do |form| %>
  <div>
    <%= form.label :first_name %>
    <%= form.text_field :first_name, required: true, autofocus: true, autocomplete: "given-name" %>
  </div>

  <div>
    <%= form.label :last_name %>
    <%= form.text_field :last_name, required: true, autocomplete: "family-name" %>
  </div>

  <div>
    <%= form.label :email_address %>
    <%= form.email_field :email_address, required: true, autocomplete: "email" %>
  </div>

  <div>
    <%= form.submit %>
  </div>
<% end %>
```

And finally, the user show view at `app/views/store/users/show.html.erb`:

```erb
<%= link_to "Back to all users", store_users_path %>

<h1><%= @user.full_name %></h1>
<p><%= @user.email_address %></p>

<div>
  <%= link_to "Edit user", edit_store_user_path(@user)  %>
  <%= button_to "Delete user", store_user_path(@user), method: :delete, data: { turbo_confirm: "Are you sure?" } %>
</div>
```

### Settings Navigation

Next, we want to add this to the Settings sidebar navigation. Since this should
be only visible to admins, we need to wrap it in a conditional to ensure the
current user is an admin.

Add the following to the settings layout in
`app/views/layouts/settings.html.erb`:

```erb#10-13
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
        <%= link_to "Users", store_users_path %>
      <% end %>
    </nav>

    <div>
      <%= yield %>
    </div>
  </section>
<% end %>

<%= render template: "layouts/application" %>
```

Separating Products Controllers
-------------------------------

Now that we have a separation for regular users and admins, we can re-organize
our Products controller to take advantage of this change. Instead of a single
controller, we can split the Products controller in two: one public facing and
one admin facing.

The public facing controller will handle the storefront views and the admin
controller will handle managing products.

### Public Products Controller

For the public storefront, we only need to let users view products. This means
`app/controllers/products_controller.rb` can be simplified down to the
following.

```ruby
class ProductsController < ApplicationController
  allow_unauthenticated_access

  def index
    @products = Product.all
  end

  def show
    @product = Product.find(params[:id])
  end
end
```

We can then adjust the views for the products controller.

First, let's copy these views to the `store` namespace since this is where we
want to manage products for the store.

```bash
$ cp -R app/views/products app/views/store
```

### Clean Up Public Product Views

Now let's remove all the create, update and destroy functionality from the
public product views.

In `app/views/products/index.html.erb`, let's remove the link to "New product".
We'll use the Settings area to create new products instead.

```diff
-<%= link_to "New product", new_product_path if authenticated? %>
```

Remove the Edit and Delete links in `app/views/products/show.html.erb`

```diff
-    <% if authenticated? %>
-      <%= link_to "Edit", edit_product_path(@product) %>
-      <%= button_to "Delete", @product, method: :delete, data: { turbo_confirm: "Are you sure?" } %>
-    <% end %>
```

Then remove:

- `app/views/products/new.html.erb`
- `app/views/products/edit.html.erb`
- `app/views/products/_form.html.erb`

### Admin Products CRUD

First, let's add the namespaced route for products to `config/routes.rb` and
also set a root route for this namespace:

```ruby#2,5
  namespace :store do
    resources :products
    resources :users

    root to: redirect("/store/products")
  end
```

And then update the settings layout navigation in
`app/views/layouts/settings.html.erb`:

```erb#12
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
      <% end %>
    </nav>

    <div>
      <%= yield %>
    </div>
  </section>
<% end %>

<%= render template: "layouts/application" %>
```

Next, create `app/controllers/store/products_controller.rb` with the following:

```ruby
class Store::ProductsController < Store::BaseController
  before_action :set_product, only: %i[ show edit update destroy ]

  def index
    @products = Product.all
  end

  def show
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      redirect_to store_product_path(@product)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to store_product_path(@product)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    redirect_to store_products_path
  end

  private
    def set_product
      @product = Product.find(params[:id])
    end

    def product_params
      params.expect(product: [ :name, :description, :featured_image, :inventory_count ])
    end
end
```

This controller is almost the same as `ProductsController` previously, but two
important changes:

1. We have `admin_access_only` to restrict access to admin users only.
2. Redirects use the `store` namespace to keep the user in the store settings
   area.

### Updating Admin Product Views

The admin views need some tweaks to work inside the `store` namespace.

First, let's fix the form by updating the `model:` argument to use the `store`
namespace. We should also display validation errors in the form while we're
here.

```erb#1-4
<%= form_with model: [ :store, product ] do |form| %>
  <% if form.object.errors.any? %>
    <div>Error: <%= form.object.errors.full_messages.first %></div>
  <% end %>

  <div>
    <%= form.label :name %>
    <%= form.text_field :name %>
  </div>

  <%# ... %>
```

Then we can remove the `authenticated?` check from
`app/views/store/products/index.html.erb` and use the `store` namespace for
links:

```erb#3,8
<h1><%= t ".title" %></h1>

<%= link_to "New product", new_store_product_path %>

<div id="products">
  <% @products.each do |product| %>
    <div>
      <%= link_to product.name, store_product_path(product) %>
    </div>
  <% end %>
</div>
```

Since this view is now in the `store` namespace, the h1 tag's relative
translation cannot be found. We can add another translation to
`config/locales/en.yml` to fix this:

```yaml#7-10
en:
  hello: "Hello world"
  products:
    index:
      title: "Products"

  store:
    products:
      index:
        title: "Products"

  activerecord:
    attributes:
      user:
        password_challenge: "Current password"
```

We need to update the Cancel link to use the `store` namespace in
`app/views/store/products/new.html.erb`:

```erb#4
<h1>New product</h1>

<%= render "form", product: @product %>
<%= link_to "Cancel", store_products_path %>
```

Do the same in `app/views/store/products/edit.html.erb`:

```erb#4
<h1>Edit product</h1>

<%= render "form", product: @product %>
<%= link_to "Cancel", store_product_path(@product) %>
```

Update `app/views/store/products/show.html.erb` with the following:

```erb#1,12-14
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
```

This updates the `show` action so that:

- Links now use to the `store` namespace.
- A "View in Storefront" link is added to make it easier for admins to see how a
  product looks to the public.
- The inventory partial is removed since that's only useful on the public
  storefront.

Since we're not using the `_inventory.html.erb` partial in the admin area, let's
remove it:

```bash
$ rm app/views/store/products/_inventory.html.erb
```

Adding Tests
------------

Let's add some tests to verify that our features work correctly.

### Authentication Test Helpers

In our test suite, we'll need to sign in users in our tests. The Rails
authentication generator has been updated to include helpers for authentication,
but your application may have been created before this, so let's ensure these
files exist before writing our tests.

In `test/test_helpers/session_test_helper.rb`, you should see the following. If
you don't, go ahead and create this file.

```ruby
module SessionTestHelper
  def sign_in_as(user)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies[:session_id] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete(:session_id)
  end
end
```

In `test/test_helper.rb`, you should see these lines. If not, go ahead and add
them.

```ruby#4,8
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    include SessionTestHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
```

### Testing Sign Up

We have a few different things to test for sign up. Let's start with a simple
test to view the page.

Create a controller test at `test/controllers/sign_ups_controller_test.rb` with
the following:

```ruby
require "test_helper"

class SignUpsControllerTest < ActionDispatch::IntegrationTest
  test "view sign up" do
    get sign_up_path
    assert_response :success
  end
end
```

This test will visit `/sign_up` and ensure that it receives a 200 OK response.

Let's run the test and see if it passes:

```bash
$ bin/rails test test/controllers/sign_ups_controller_test.rb:4
Running 1 tests in a single process (parallelization threshold is 50)
Run options: --seed 5967

# Running:

.

Finished in 0.559107s, 1.7886 runs/s, 1.7886 assertions/s.
1 runs, 1 assertions, 0 failures, 0 errors, 0 skips
```

Next, let's sign in a user and try to visit the sign up page. In this situation,
the user should be redirected because they're already authenticated.

Add the following test to the file.

```ruby
test "view sign up when authenticated" do
  sign_in_as users(:one)
  get sign_up_path
  assert_redirected_to root_path
end
```

Run the tests again and you should see this one passes too.

Next, let's add a test to ensure a new user is created when they fill out the
form.

```ruby
test "successful sign up" do
  assert_difference "User.count" do
    post sign_up_path, params: { user: { first_name: "Example", last_name: "User", email_address: "example@user.org", password: "password", password_confirmation: "password" } }
    assert_redirected_to root_path
  end
end
```

For this test, we need submit params with a POST request to test the `create`
action.

Let's also test with invalid data to ensure the controller returns an error.

```ruby
test "invalid sign up" do
  assert_no_difference "User.count" do
    post sign_up_path, params: { user: { email_address: "example@user.org", password: "password", password_confirmation: "password" } }
    assert_response :unprocessable_entity
  end
end
```

This test should be invalid because the user's name is missing. Since this
request is invalid, we need to assert the response is a 422 Unprocessable
Entity. We can also assert that there is no difference in the `User.count` to
ensure no User was created.

Another important test to add is ensuring that sign up does not accept the
`admin` attribute.

```ruby
test "sign up ignores admin attribute" do
  assert_difference "User.count" do
    post sign_up_path, params: { user: { first_name: "Example", last_name: "User", email_address: "example@user.org", password: "password", password_confirmation: "password", admin: true } }
    assert_redirected_to root_path
  end
  refute User.find_by(email_address: "example@user.org").admin?
end
```

This test is just like a successful sign up, but it tries to set `admin: true`.
After asserting the user is created, we also need to assert that the user is
_not_ an admin.

### Testing Email Changes

Changing a user's email is a multi-step process that is important to test as
well.

To start, let's create a controller test to ensure the email update form handles
everything correctly.

In `test/controllers/settings/emails_controller_test.rb` add the following:

```ruby
require "test_helper"

class Settings::EmailsControllerTest < ActionDispatch::IntegrationTest
  test "validates current password" do
    user = users(:one)
    sign_in_as user
    patch settings_email_path, params: { user: { password_challenge: "invalid", unconfirmed_email: "new@example.org" } }
    assert_response :unprocessable_entity
    assert_nil user.reload.unconfirmed_email
    assert_no_emails
  end
end
```

Our first test is going to be a submission with an invalid password challenge.
For this, we want to ensure the response is an error and the unconfirmed email
was not changed. We can also ensure that no emails were sent in this case as
well.

Then we can write a test for the success case:

```ruby
test "sends email confirmation on successful update" do
  user = users(:one)
  sign_in_as user
  patch settings_email_path, params: { user: { password_challenge: "password", unconfirmed_email: "new@example.org" } }
  assert_response :redirect
  assert_equal "new@example.org", user.reload.unconfirmed_email
  assert_enqueued_email_with UserMailer, :email_confirmation, params: { user: user }
end
```

This tests submits successful params, confirms the email is saved to the
database, the user was redirected and the confirmation email was queued for
delivery.

Let's run these tests and make sure they pass:

```bash
$ bin/rails test test/controllers/settings/emails_controller_test.rb
Running 2 tests in a single process (parallelization threshold is 50)
Run options: --seed 31545

# Running:

..

Finished in 0.954590s, 2.0951 runs/s, 6.2854 assertions/s.
2 runs, 6 assertions, 0 failures, 0 errors, 0 skips
```

We also need to test the `Email::ConfirmationsController` to ensure confirmation
tokens are validated the email update process completes successfully.

Let's add another controller test at
`test/controllers/email/confirmations_controller_test.rb` with the following:

```ruby
require "test_helper"

class Email::ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  test "invalid tokens are ignored" do
    user = users(:one)
    previous_email = user.email_address
    user.update(unconfirmed_email: "new@example.org")
    get email_confirmation_path(token: "invalid")
    assert_equal "Invalid token.", flash[:alert]
    user.reload
    assert_equal previous_email, user.email_address
  end

  test "email is updated with a valid token" do
    user = users(:one)
    user.update(unconfirmed_email: "new@example.org")
    get email_confirmation_path(token: user.generate_token_for(:email_confirmation))
    assert_equal "Your email has been confirmed.", flash[:notice]
    user.reload
    assert_equal "new@example.org", user.email_address
    assert_nil user.unconfirmed_email
  end
end
```

The first test simulates a user confirming their email change with an invalid
token. We assert the error message was set and the email address did not change.

The second test uses valid token and asserts the success notice was set and the
email address was updated in the database.

We need to fix one more test related to email confirmations and that is the
automatically generated tests for `UserMailer`. Let's update that to match our
application logic.

Change `test/mailers/user_mailer_test.rb` to the following:

```ruby
require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "email_confirmation" do
    user = users(:one)
    user.update(unconfirmed_email: "new@example.org")
    mail = UserMailer.with(user: user).email_confirmation
    assert_equal "Email confirmation", mail.subject
    assert_equal [ "new@example.org" ], mail.to
    assert_match "/email/confirmations/", mail.body.encoded
  end
end
```

This test ensures the user has an `unconfirmed_email` and the email is sent to
that email address. It also ensures that the email body contains the path to
`/email/confirmations` so we know it contains the link for the user to click and
confirm their new email address.

### Testing Settings

Another area that we should test is the Settings navigation. We want to ensure
the appropriate links are visible to admins and not visible to regular users.

Let's first create an admin user fixture in `test/fixtures/users.yml` and add
names to the fixtures so they pass validations.

```yaml#6-7,12-13,15-20
<% password_digest = BCrypt::Password.create("password") %>

one:
  email_address: one@example.com
  password_digest: <%= password_digest %>
  first_name: User
  last_name: One

two:
  email_address: two@example.com
  password_digest: <%= password_digest %>
  first_name: User
  last_name: Two

admin:
  email_address: admin@example.com
  password_digest: <%= password_digest %>
  first_name: Admin
  last_name: User
  admin: true
```

Then create a test file for this at `test/integration/settings_test.rb`.

```ruby
require "test_helper"

class SettingsTest < ActionDispatch::IntegrationTest
  test "user settings nav" do
    sign_in_as users(:one)
    get settings_profile_path
    assert_dom "h4", "Account Settings"
    assert_not_dom "a", "Store Settings"
  end

  test "admin settings nav" do
    sign_in_as users(:admin)
    get settings_profile_path
    assert_dom "h4", "Account Settings"
    assert_dom "h4", "Store Settings"
  end
end
```

These tests ensure that only admins will see the Store settings in the navbar.

You can run these tests with:

```bash
$ bin/rails test test/integration/settings_test.rb
```

We also want to ensure regular users cannot access the Store settings for
Products and Users. Let's add some tests for that.

```ruby
test "regular user cannot access /store/products" do
  sign_in_as users(:one)
  get store_products_path
  assert_response :redirect
  assert_equal "You aren't allowed to do that.", flash[:alert]
end

test "regular user cannot access /store/users" do
  sign_in_as users(:one)
  get store_users_path
  assert_response :redirect
  assert_equal "You aren't allowed to do that.", flash[:alert]
end
```

These tests use a regular user to access the admin only areas and ensures they
are redirected away with a flash message.

Let's complete these tests by ensuring that admin users _can_ access these
areas.

```ruby
test "admins can access /store/products" do
  sign_in_as users(:admin)
  get store_products_path
  assert_response :success
end

test "admins can access /store/users" do
  sign_in_as users(:admin)
  get store_users_path
  assert_response :success
end
```

Run the test file again and you should see they all pass.

```bash
$ bin/rails test test/integration/settings_test.rb
Running 6 tests in a single process (parallelization threshold is 50)
Run options: --seed 33354

# Running:

......

Finished in 0.625542s, 9.5917 runs/s, 12.7889 assertions/s.
6 runs, 8 assertions, 0 failures, 0 errors, 0 skips
```

And let's run the full test suite one more time to make sure all the tests pass.

```bash
$ bin/rails test
Running 18 tests in a single process (parallelization threshold is 50)
Run options: --seed 38561

# Running:

..................

Finished in 0.915621s, 19.6588 runs/s, 51.3313 assertions/s.
18 runs, 47 assertions, 0 failures, 0 errors, 0 skips
```

Great! Now, let's deploy this to production.

Deploying To Production
-----------------------

Since we previously setup Kamal in the
[Getting Started Guide](getting_started.html#deploying-to-production), we just
need to push our code changes to our Git repository and run:

```bash
$ bin/kamal deploy
```

This will build a new container for our application and deploy it to our
production server.

### Setting Admins In Production

If you added `attr_readonly :admin`, you'll need to use the dbconsole to update
your account.

```bash
$ bin/kamal dbc
UPDATE users SET admin=true WHERE users.email='you@example.org';
.quit
```

Otherwise, you can use the Rails console to update your account.

```bash
$ bin/kamal console
irb> User.find_by(email: "you@example.org").update(admin: true)
```

You can now access the Store settings in production with your account.

What's Next
-----------

You did it! Your e-commerce store now supports user sign up, account management,
and an admin area for managing products and users.

Here are a few ideas to build on to this:

- Add shareable wishlists
- Write more tests to ensure the application works correctly
- Add payments to buy products

Happy building!

[Return to all tutorials](https://rubyonrails.org/docs/tutorials)
