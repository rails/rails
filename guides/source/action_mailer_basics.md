Action Mailer Basics
====================

This guide should provide you with all you need to get started in sending and receiving emails from and to your application, and many internals of Action Mailer. It also covers how to test your mailers.

After reading this guide, you will know:

* How to send and receive email within a Rails application.
* How to generate and edit an Action Mailer class and mailer view.
* How to configure Action Mailer for your environment.
* How to test your Action Mailer classes.
--------------------------------------------------------------------------------

Introduction
------------

Action Mailer allows you to send emails from your application using a mailer model and views. So, in Rails, emails are used by creating mailers that inherit from `ActionMailer::Base` and live in `app/mailers`. Those mailers have associated views that appear alongside controller views in `app/views`.

Sending Emails
--------------

This section will provide a step-by-step guide to creating a mailer and its views.

### Walkthrough to Generating a Mailer

#### Create the Mailer

```bash
$ rails generate mailer UserMailer
create  app/mailers/user_mailer.rb
invoke  erb
create    app/views/user_mailer
invoke  test_unit
create    test/mailers/user_mailer_test.rb
```

So we got the mailer, the views, and the tests.

#### Edit the Mailer

`app/mailers/user_mailer.rb` contains an empty mailer:

```ruby
class UserMailer < ActionMailer::Base
  default from: 'from@example.com'
end
```

Let's add a method called `welcome_email`, that will send an email to the user's registered email address:

```ruby
class UserMailer < ActionMailer::Base
  default from: 'notifications@example.com'

  def welcome_email(user)
    @user = user
    @url  = 'http://example.com/login'
    mail(to: user.email, subject: 'Welcome to My Awesome Site')
  end
end
```

Here is a quick explanation of the items presented in the preceding method. For a full list of all available options, please have a look further down at the Complete List of Action Mailer user-settable attributes section.

* `default Hash` - This is a hash of default values for any email you send, in this case we are setting the `:from` header to a value for all messages in this class, this can be overridden on a per email basis
* `mail` - The actual email message, we are passing the `:to` and `:subject` headers in.

Just like controllers, any instance variables we define in the method become available for use in the views.

#### Create a Mailer View

Create a file called `welcome_email.html.erb` in `app/views/user_mailer/`. This will be the template used for the email, formatted in HTML:

```html+erb
<!DOCTYPE html>
<html>
  <head>
    <meta content='text/html; charset=UTF-8' http-equiv='Content-Type' />
  </head>
  <body>
    <h1>Welcome to example.com, <%= @user.name %></h1>
    <p>
      You have successfully signed up to example.com,
      your username is: <%= @user.login %>.<br/>
    </p>
    <p>
      To login to the site, just follow this link: <%= @url %>.
    </p>
    <p>Thanks for joining and have a great day!</p>
  </body>
</html>
```

It is also a good idea to make a text part for this email. To do this, create a file called `welcome_email.text.erb` in `app/views/user_mailer/`:

```erb
Welcome to example.com, <%= @user.name %>
===============================================

You have successfully signed up to example.com,
your username is: <%= @user.login %>.

To login to the site, just follow this link: <%= @url %>.

Thanks for joining and have a great day!
```

When you call the `mail` method now, Action Mailer will detect the two templates (text and HTML) and automatically generate a `multipart/alternative` email.

#### Wire It Up So That the System Sends the Email When a User Signs Up

There are several ways to do this, some people create Rails Observers to fire off emails, others do it inside of the User Model. However, mailers are really just another way to render a view. Instead of rendering a view and sending out the HTTP protocol, they are just sending it out through the Email protocols instead. Due to this, it makes sense to just have your controller tell the mailer to send an email when a user is successfully created.

Setting this up is painfully simple.

First off, we need to create a simple `User` scaffold:

```bash
$ rails generate scaffold user name:string email:string login:string
$ rake db:migrate
```

Now that we have a user model to play with, we will just edit the `app/controllers/users_controller.rb` make it instruct the UserMailer to deliver an email to the newly created user by editing the create action and inserting a call to `UserMailer.welcome_email` right after the user is successfully saved:

```ruby
class UsersController < ApplicationController
  # POST /users
  # POST /users.json
  def create
    @user = User.new(params[:user])

    respond_to do |format|
      if @user.save
        # Tell the UserMailer to send a welcome Email after save
        UserMailer.welcome_email(@user).deliver

        format.html { redirect_to(@user, notice: 'User was successfully created.') }
        format.json { render json: @user, status: :created, location: @user }
      else
        format.html { render action: 'new' }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end
end
```

This provides a much simpler implementation that does not require the registering of observers and the like.

The method `welcome_email` returns a `Mail::Message` object which can then just be told `deliver` to send itself out.

### Auto encoding header values

Action Mailer now handles the auto encoding of multibyte characters inside of headers and bodies.

If you are using UTF-8 as your character set, you do not have to do anything special, just go ahead and send in UTF-8 data to the address fields, subject, keywords, filenames or body of the email and Action Mailer will auto encode it into quoted printable for you in the case of a header field or Base64 encode any body parts that are non US-ASCII.

For more complex examples such as defining alternate character sets or self-encoding text first, please refer to the Mail library.

### Complete List of Action Mailer Methods

There are just three methods that you need to send pretty much any email message:

* `headers` - Specifies any header on the email you want. You can pass a hash of header field names and value pairs, or you can call `headers[:field_name] = 'value'`.
* `attachments` - Allows you to add attachments to your email. For example, `attachments['file-name.jpg'] = File.read('file-name.jpg')`.
* `mail` - Sends the actual email itself. You can pass in headers as a hash to the mail method as a parameter, mail will then create an email, either plain text, or multipart, depending on what email templates you have defined.

#### Custom Headers

Defining custom headers are simple, you can do it one of three ways:

* Defining a header field as a parameter to the `mail` method:

    ```ruby
    mail('X-Spam' => value)
    ```

* Passing in a key value assignment to the `headers` method:

    ```ruby
    headers['X-Spam'] = value
    ```

* Passing a hash of key value pairs to the `headers` method:

    ```ruby
    headers {'X-Spam' => value, 'X-Special' => another_value}
    ```

TIP: All `X-Value` headers per the RFC2822 can appear more than once. If you want to delete an `X-Value` header, you need to assign it a value of `nil`.

#### Adding Attachments

Adding attachments has been simplified in Action Mailer 3.0.

* Pass the file name and content and Action Mailer and the Mail gem will automatically guess the mime_type, set the encoding and create the attachment.

    ```ruby
    attachments['filename.jpg'] = File.read('/path/to/filename.jpg')
    ```

NOTE: Mail will automatically Base64 encode an attachment. If you want something different, pre-encode your content and pass in the encoded content and encoding in a `Hash` to the `attachments` method.

* Pass the file name and specify headers and content and Action Mailer and Mail will use the settings you pass in.

    ```ruby
    encoded_content = SpecialEncode(File.read('/path/to/filename.jpg'))
    attachments['filename.jpg'] = {mime_type: 'application/x-gzip',
                                   encoding: 'SpecialEncoding',
                                   content: encoded_content }
    ```

NOTE: If you specify an encoding, Mail will assume that your content is already encoded and not try to Base64 encode it.

#### Making Inline Attachments

Action Mailer 3.0 makes inline attachments, which involved a lot of hacking in pre 3.0 versions, much simpler and trivial as they should be.

* Firstly, to tell Mail to turn an attachment into an inline attachment, you just call `#inline` on the attachments method within your Mailer:

    ```ruby
    def welcome
      attachments.inline['image.jpg'] = File.read('/path/to/image.jpg')
    end
    ```

* Then in your view, you can just reference `attachments[]` as a hash and specify which attachment you want to show, calling `url` on it and then passing the result into the `image_tag` method:

    ```html+erb
    <p>Hello there, this is our image</p>

    <%= image_tag attachments['image.jpg'].url %>
    ```

* As this is a standard call to `image_tag` you can pass in an options hash after the attachment URL as you could for any other image:

    ```html+erb
    <p>Hello there, this is our image</p>

    <%= image_tag attachments['image.jpg'].url, alt: 'My Photo',
                                                class: 'photos' %>
    ```

#### Sending Email To Multiple Recipients

It is possible to send email to one or more recipients in one email (e.g., informing all admins of a new signup) by setting the list of emails to the `:to` key. The list of emails can be an array of email addresses or a single string with the addresses separated by commas.

```ruby
class AdminMailer < ActionMailer::Base
  default to: Proc.new { Admin.pluck(:email) },
          from: 'notification@example.com'

  def new_registration(user)
    @user = user
    mail(subject: "New User Signup: #{@user.email}")
  end
end
```

The same format can be used to set carbon copy (Cc:) and blind carbon copy (Bcc:) recipients, by using the `:cc` and `:bcc` keys respectively.

#### Sending Email With Name

Sometimes you wish to show the name of the person instead of just their email address when they receive the email. The trick to doing that is
to format the email address in the format `"Name <email>"`.

```ruby
def welcome_email(user)
  @user = user
  email_with_name = "#{@user.name} <#{@user.email}>"
  mail(to: email_with_name, subject: 'Welcome to My Awesome Site')
end
```

### Mailer Views

Mailer views are located in the `app/views/name_of_mailer_class` directory. The specific mailer view is known to the class because its name is the same as the mailer method. In our example from above, our mailer view for the `welcome_email` method will be in `app/views/user_mailer/welcome_email.html.erb` for the HTML version and `welcome_email.text.erb` for the plain text version.

To change the default mailer view for your action you do something like:

```ruby
class UserMailer < ActionMailer::Base
  default from: 'notifications@example.com'

  def welcome_email(user)
    @user = user
    @url  = 'http://example.com/login'
    mail(to: user.email,
         subject: 'Welcome to My Awesome Site',
         template_path: 'notifications',
         template_name: 'another')
  end
end
```

In this case it will look for templates at `app/views/notifications` with name `another`.  You can also specify an array of paths for `template_path`, and they will be searched in order.

If you want more flexibility you can also pass a block and render specific templates or even render inline or text without using a template file:

```ruby
class UserMailer < ActionMailer::Base
  default from: 'notifications@example.com'

  def welcome_email(user)
    @user = user
    @url  = 'http://example.com/login'
    mail(to: user.email,
         subject: 'Welcome to My Awesome Site') do |format|
      format.html { render 'another_template' }
      format.text { render text: 'Render text' }
    end
  end

end
```

This will render the template 'another_template.html.erb' for the HTML part and use the rendered text for the text part. The render command is the same one used inside of Action Controller, so you can use all the same options, such as `:text`, `:inline` etc.

### Action Mailer Layouts

Just like controller views, you can also have mailer layouts. The layout name needs to be the same as your mailer, such as `user_mailer.html.erb` and `user_mailer.text.erb` to be automatically recognized by your mailer as a layout.

In order to use a different file just use:

```ruby
class UserMailer < ActionMailer::Base
  layout 'awesome' # use awesome.(html|text).erb as the layout
end
```

Just like with controller views, use `yield` to render the view inside the layout.

You can also pass in a `layout: 'layout_name'` option to the render call inside the format block to specify different layouts for different actions:

```ruby
class UserMailer < ActionMailer::Base
  def welcome_email(user)
    mail(to: user.email) do |format|
      format.html { render layout: 'my_layout' }
      format.text
    end
  end
end
```

Will render the HTML part using the `my_layout.html.erb` file and the text part with the usual `user_mailer.text.erb` file if it exists.

### Generating URLs in Action Mailer Views

URLs can be generated in mailer views using `url_for` or named routes.

Unlike controllers, the mailer instance doesn't have any context about the incoming request so you'll need to provide the `:host`, `:controller`, and `:action`:

```erb
<%= url_for(host: 'example.com',
            controller: 'welcome',
            action: 'greeting') %>
```

When using named routes you only need to supply the `:host`:

```erb
<%= user_url(@user, host: 'example.com') %>
```

Email clients have no web context and so paths have no base URL to form complete web addresses. Thus, when using named routes only the "_url" variant makes sense.

It is also possible to set a default host that will be used in all mailers by setting the `:host` option as a configuration option in `config/application.rb`:

```ruby
config.action_mailer.default_url_options = { host: 'example.com' }
```

If you use this setting, you should pass the `only_path: false` option when using `url_for`. This will ensure that absolute URLs are generated because the `url_for` view helper will, by default, generate relative URLs when a `:host` option isn't explicitly provided.

### Sending Multipart Emails

Action Mailer will automatically send multipart emails if you have different templates for the same action. So, for our UserMailer example, if you have `welcome_email.text.erb` and `welcome_email.html.erb` in `app/views/user_mailer`, Action Mailer will automatically send a multipart email with the HTML and text versions setup as different parts.

The order of the parts getting inserted is determined by the `:parts_order` inside of the `ActionMailer::Base.default` method.

### Sending Emails with Attachments

Attachments can be added by using the `attachments` method:

```ruby
class UserMailer < ActionMailer::Base
  def welcome_email(user)
    @user = user
    @url  = user_url(@user)
    attachments['terms.pdf'] = File.read('/path/terms.pdf')
    mail(to: user.email,
         subject: 'Please see the Terms and Conditions attached')
  end
end
```

The above will send a multipart email with an attachment, properly nested with the top level being `multipart/mixed` and the first part being a `multipart/alternative` containing the plain text and HTML email messages.

### Sending Emails with Dynamic Delivery Options

If you wish to override the default delivery options (e.g. SMTP credentials) while delivering emails, you can do this using `delivery_method_options` in the mailer action.

```ruby
class UserMailer < ActionMailer::Base
  def welcome_email(user,company)
    @user = user
    @url  = user_url(@user)
    delivery_options = { user_name: company.smtp_user, password: company.smtp_password, address: company.smtp_host }
    mail(to: user.email, subject: "Please see the Terms and Conditions attached", delivery_method_options: delivery_options)
  end
end
```

Receiving Emails
----------------

Receiving and parsing emails with Action Mailer can be a rather complex endeavor. Before your email reaches your Rails app, you would have had to configure your system to somehow forward emails to your app, which needs to be listening for that. So, to receive emails in your Rails app you'll need to:

* Implement a `receive` method in your mailer.

* Configure your email server to forward emails from the address(es) you would like your app to receive to `/path/to/app/script/rails runner 'UserMailer.receive(STDIN.read)'`.

Once a method called `receive` is defined in any mailer, Action Mailer will parse the raw incoming email into an email object, decode it, instantiate a new mailer, and pass the email object to the mailer `receive` instance method. Here's an example:

```ruby
class UserMailer < ActionMailer::Base
  def receive(email)
    page = Page.find_by_address(email.to.first)
    page.emails.create(
      subject: email.subject,
      body: email.body
    )

    if email.has_attachments?
      email.attachments.each do |attachment|
        page.attachments.create({
          file: attachment,
          description: email.subject
        })
      end
    end
  end
end
```

Action Mailer Callbacks
---------------------------

Action Mailer allows for you to specify a `before_action`, `after_action` and 'around_action'.

* Filters can be specified with a block or a symbol to a method in the mailer class similar to controllers.

* You could use a `before_action` to prepopulate the mail object with defaults, delivery_method_options or insert default headers and attachments.

* You could use an `after_action` to do similar setup as a `before_action` but using instance variables set in your mailer action.

```ruby
class UserMailer < ActionMailer::Base
  after_action :set_delivery_options, :prevent_delivery_to_guests, :set_business_headers

  def feedback_message(business, user)
    @business = business
    @user = user
    mail
  end

  def campaign_message(business, user)
    @business = business
    @user = user
  end

  private

  def set_delivery_options
    # You have access to the mail instance and @business and @user instance variables here
    if @business && @business.has_smtp_settings?
      mail.delivery_method.settings.merge!(@business.smtp_settings)
    end
  end

  def prevent_delivery_to_guests
    if @user && @user.guest?
      mail.perform_deliveries = false
    end
  end

  def set_business_headers
    if @business
      headers["X-SMTPAPI-CATEGORY"] = @business.code
    end
  end
end
```

* Mailer Filters abort further processing if body is set to a non-nil value.

Using Action Mailer Helpers
---------------------------

Action Mailer now just inherits from Abstract Controller, so you have access to the same generic helpers as you do in Action Controller.

Action Mailer Configuration
---------------------------

The following configuration options are best made in one of the environment files (environment.rb, production.rb, etc...)

| Configuration | Description |
|---------------|-------------|
|`template_root`|Determines the base from which template references will be made.|
|`logger`|Generates information on the mailing run if available. Can be set to `nil` for no logging. Compatible with both Ruby's own `Logger` and `Log4r` loggers.|
|`smtp_settings`|Allows detailed configuration for `:smtp` delivery method:<ul><li>`:address` - Allows you to use a remote mail server. Just change it from its default "localhost" setting.</li><li>`:port`  - On the off chance that your mail server doesn't run on port 25, you can change it.</li><li>`:domain` - If you need to specify a HELO domain, you can do it here.</li><li>`:user_name` - If your mail server requires authentication, set the username in this setting.</li><li>`:password` - If your mail server requires authentication, set the password in this setting.</li><li>`:authentication` - If your mail server requires authentication, you need to specify the authentication type here. This is a symbol and one of `:plain`, `:login`, `:cram_md5`.</li><li>`:enable_starttls_auto` - Set this to `false` if there is a problem with your server certificate that you cannot resolve.</li></ul>|
|`sendmail_settings`|Allows you to override options for the `:sendmail` delivery method.<ul><li>`:location` - The location of the sendmail executable. Defaults to `/usr/sbin/sendmail`.</li><li>`:arguments` - The command line arguments to be passed to sendmail. Defaults to `-i -t`.</li></ul>|
|`raise_delivery_errors`|Whether or not errors should be raised if the email fails to be delivered. This only works if the external email server is configured for immediate delivery.|
|`delivery_method`|Defines a delivery method. Possible values are `:smtp` (default), `:sendmail`, `:file` and `:test`.|
|`perform_deliveries`|Determines whether deliveries are actually carried out when the `deliver` method is invoked on the Mail message. By default they are, but this can be turned off to help functional testing.|
|`deliveries`|Keeps an array of all the emails sent out through the Action Mailer with delivery_method :test. Most useful for unit and functional testing.|
|`default_options`|Allows you to set default values for the `mail` method options (`:from`, `:reply_to`, etc.).|
|`async`|Setting this flag will turn on asynchronous message sending, message rendering and delivery will be pushed to `Rails.queue` for processing.|

### Example Action Mailer Configuration

An example would be adding the following to your appropriate `config/environments/$RAILS_ENV.rb` file:

```ruby
config.action_mailer.delivery_method = :sendmail
# Defaults to:
# config.action_mailer.sendmail_settings = {
#   location: '/usr/sbin/sendmail',
#   arguments: '-i -t'
# }
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
config.action_mailer.default_options = {from: 'no-replay@example.org'}
```

### Action Mailer Configuration for GMail

As Action Mailer now uses the Mail gem, this becomes as simple as adding to your `config/environments/$RAILS_ENV.rb` file:

```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address:              'smtp.gmail.com',
  port:                 587,
  domain:               'baci.lindsaar.net',
  user_name:            '<username>',
  password:             '<password>',
  authentication:       'plain',
  enable_starttls_auto: true  }
```

Mailer Testing
--------------

By default Action Mailer does not send emails in the test environment. They are just added to the `ActionMailer::Base.deliveries` array.

Testing mailers normally involves two things: One is that the mail was queued, and the other one that the email is correct. With that in mind, we could test our example mailer from above like so:

```ruby
class UserMailerTest < ActionMailer::TestCase
  def test_welcome_email
    user = users(:some_user_in_your_fixtures)

    # Send the email, then test that it got queued
    email = UserMailer.welcome_email(user).deliver
    assert !ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_equal [user.email], email.to
    assert_equal 'Welcome to My Awesome Site', email.subject
    assert_match "<h1>Welcome to example.com, #{user.name}</h1>", email.body.to_s
    assert_match 'you have joined to example.com community', email.body.to_s
  end
end
```

In the test we send the email and store the returned object in the `email` variable. We then ensure that it was sent (the first assert), then, in the second batch of assertions, we ensure that the email does indeed contain what we expect.

Asynchronous
------------

Rails provides a Synchronous Queue by default. If you want to use an Asynchronous one you will need to configure an async Queue provider like Resque. Queue providers are supposed to have a Railtie where they configure it's own async queue.

### Custom Queues

If you need a different queue than `Rails.queue` for your mailer you can use `ActionMailer::Base.queue=`:

```ruby
class WelcomeMailer < ActionMailer::Base
  self.queue = MyQueue.new
end
```

or adding to your `config/environments/$RAILS_ENV.rb`:

```ruby
config.action_mailer.queue = MyQueue.new
```

Your custom queue should expect a job that responds to `#run`.
