**DO NOT READ THIS FILE IN GITHUB, GUIDES ARE PUBLISHED IN http://guides.rubyonrails.org.**

A Guide to Testing Rails Applications
=====================================

This guide covers built-in mechanisms in Rails for testing your application.

After reading this guide, you will know:

* Rails testing terminology.
* How to write unit, functional, and integration tests for your application.
* Other popular testing approaches and plugins.

--------------------------------------------------------------------------------

Why Write Tests for your Rails Applications?
--------------------------------------------

Rails makes it super easy to write your tests. It starts by producing skeleton test code while you are creating your models and controllers.

By simply running your Rails tests you can ensure your code adheres to the desired functionality even after some major code refactoring.

Rails tests can also simulate browser requests and thus you can test your application's response without having to test it through your browser.

Introduction to Testing
-----------------------

Testing support was woven into the Rails fabric from the beginning. It wasn't an "oh! let's bolt on support for running tests because they're new and cool" epiphany. Just about every Rails application interacts heavily with a database and, as a result, your tests will need a database to interact with as well. To write efficient tests, you'll need to understand how to set up this database and populate it with sample data.

### The Test Environment

By default, every Rails application has three environments: development, test, and production. The database for each one of them is configured in `config/database.yml`.

A dedicated test database allows you to set up and interact with test data in isolation. This way your tests can mangle test data with confidence, without worrying about the data in the development or production databases.

Also, each environment's configuration can be modified similarly. In this case, we can modify our test environment by changing the options found in `config/environments/test.rb`.

### Rails Sets up for Testing from the Word Go

Rails creates a `test` directory for you as soon as you create a Rails project using `rails new` _application_name_. If you list the contents of this directory then you shall see:

```bash
$ ls -F test
controllers/    helpers/        mailers/        test_helper.rb
fixtures/       integration/    models/
```

The `models` directory is meant to hold tests for your models, the `controllers` directory is meant to hold tests for your controllers and the `integration` directory is meant to hold tests that involve any number of controllers interacting. There is also a directory for testing your mailers and one for testing view helpers.

Fixtures are a way of organizing test data; they reside in the `fixtures` directory.

The `test_helper.rb` file holds the default configuration for your tests.

### The Low-Down on Fixtures

For good tests, you'll need to give some thought to setting up test data.
In Rails, you can handle this by defining and customizing fixtures.
You can find comprehensive documentation in the [Fixtures API documentation](http://api.rubyonrails.org/classes/ActiveRecord/FixtureSet.html).

#### What Are Fixtures?

_Fixtures_ is a fancy word for sample data. Fixtures allow you to populate your testing database with predefined data before your tests run. Fixtures are database independent written in YAML. There is one file per model.

You'll find fixtures under your `test/fixtures` directory. When you run `rails generate model` to create a new model fixture stubs will be automatically created and placed in this directory.

#### YAML

YAML-formatted fixtures are a human-friendly way to describe your sample data. These types of fixtures have the **.yml** file extension (as in `users.yml`).

Here's a sample YAML fixture file:

```yaml
# lo & behold! I am a YAML comment!
david:
  name: David Heinemeier Hansson
  birthday: 1979-10-15
  profession: Systems development

steve:
  name: Steve Ross Kellock
  birthday: 1974-09-27
  profession: guy with keyboard
```

Each fixture is given a name followed by an indented list of colon-separated key/value pairs. Records are typically separated by a blank space. You can place comments in a fixture file by using the # character in the first column.

If you are working with [associations](/association_basics.html), you can simply
define a reference node between two different fixtures. Here's an example with
a `belongs_to`/`has_many` association:

```yaml
# In fixtures/categories.yml
about:
  name: About

# In fixtures/articles.yml
one:
  title: Welcome to Rails!
  body: Hello world!
  category: about
```

Notice the `category` key of the `one` article found in `fixtures/articles.yml` has a value of `about`. This tells Rails to load the category `about` found in `fixtures/categories.yml`.

NOTE: For associations to reference one another by name, you cannot specify the `id:` attribute on the associated fixtures. Rails will auto assign a primary key to be consistent between runs. For more information on this association behavior please read the [Fixtures API documentation](http://api.rubyonrails.org/classes/ActiveRecord/FixtureSet.html).

#### ERB'in It Up

ERB allows you to embed Ruby code within templates. The YAML fixture format is pre-processed with ERB when Rails loads fixtures. This allows you to use Ruby to help you generate some sample data. For example, the following code generates a thousand users:

```erb
<% 1000.times do |n| %>
user_<%= n %>:
  username: <%= "user#{n}" %>
  email: <%= "user#{n}@example.com" %>
<% end %>
```

#### Fixtures in Action

Rails by default automatically loads all fixtures from the `test/fixtures` directory for your models and controllers test. Loading involves three steps:

* Remove any existing data from the table corresponding to the fixture
* Load the fixture data into the table
* Dump the fixture data into a method in case you want to access it directly

TIP: In order to remove existing data from the database, Rails tries to disable referential integrity triggers (like foreign keys and check constraints). If you are getting annoying permission errors on running tests, make sure the database user has privilege to disable these triggers in testing environment. (In PostgreSQL, only superusers can disable all triggers. Read more about PostgreSQL permissions [here](http://blog.endpoint.com/2012/10/postgres-system-triggers-error.html))

#### Fixtures are Active Record objects

Fixtures are instances of Active Record. As mentioned in point #3 above, you can access the object directly because it is automatically available as a method whose scope is local of the test case. For example:

```ruby
# this will return the User object for the fixture named david
users(:david)

# this will return the property for david called id
users(:david).id

# one can also access methods available on the User class
email(david.girlfriend.email, david.location_tonight)
```

### Rake Tasks for Running your Tests

Rails comes with a number of built-in rake tasks to help with testing. The
table below lists the commands included in the default Rakefile when a Rails
project is created.

| Tasks                   | Description |
| ----------------------- | ----------- |
| `rake test`             | Runs all tests in the `test` directory. You can also run `rake` and Rails will run all tests by default |
| `rake test:controllers` | Runs all the controller tests from `test/controllers` |
| `rake test:functionals` | Runs all the functional tests from `test/controllers`, `test/mailers`, and `test/functional` |
| `rake test:helpers`     | Runs all the helper tests from `test/helpers` |
| `rake test:integration` | Runs all the integration tests from `test/integration` |
| `rake test:jobs`        | Runs all the job tests from `test/jobs` |
| `rake test:mailers`     | Runs all the mailer tests from `test/mailers` |
| `rake test:models`      | Runs all the model tests from `test/models` |
| `rake test:units`       | Runs all the unit tests from `test/models`, `test/helpers`, and `test/unit` |
| `rake test:db`          | Runs all tests in the `test` directory and resets the db |

We will cover each of types Rails tests listed above in this guide.

Unit Testing your Models
------------------------

In Rails, unit tests are what you write to test your models.

For this guide we will be using the application we built in the [Getting Started with Rails](getting_started.html) guide.

If you remember when you used the `rails generate scaffold` command from earlier. We created our first resource among other things it created a test stub in the `test/models` directory:

```bash
$ bin/rails generate scaffold article title:string body:text
...
create  app/models/article.rb
create  test/models/article_test.rb
create  test/fixtures/articles.yml
...
```

The default test stub in `test/models/article_test.rb` looks like this:

```ruby
require 'test_helper'

class ArticleTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
```

A line by line examination of this file will help get you oriented to Rails testing code and terminology.

```ruby
require 'test_helper'
```

By requiring this file, `test_helper.rb` the default configuration to run our tests is loaded. We will include this with all the tests we write, so any methods added to this file are available to all your tests.

```ruby
class ArticleTest < ActiveSupport::TestCase
```

The `ArticleTest` class defines a _test case_ because it inherits from `ActiveSupport::TestCase`. `ArticleTest` thus has all the methods available from `ActiveSupport::TestCase`. Later in this guide, you'll see some of the methods it gives you.

Any method defined within a class inherited from `Minitest::Test`
(which is the superclass of `ActiveSupport::TestCase`) that begins with `test_` (case sensitive) is simply called a test. So, methods defined as `test_password` and `test_valid_password` are legal test names and are run automatically when the test case is run.

Rails also adds a `test` method that takes a test name and a block. It generates a normal `Minitest::Unit` test with method names prefixed with `test_`. So you don't have to worry about naming the methods, and you can write something like:

```ruby
test "the truth" do
  assert true
end
```

Which is approximately the same as writing this:

```ruby
def test_the_truth
  assert true
end
```

However only the `test` macro allows a more readable test name. You can still use regular method definitions though.

NOTE: The method name is generated by replacing spaces with underscores. The result does not need to be a valid Ruby identifier though, the name may contain punctuation characters etc. That's because in Ruby technically any string may be a method name. This may require use of `define_method` and `send` calls to function properly, but formally there's little restriction on the name.

Next, let's look at our first assertion:

```ruby
assert true
```

An assertion is a line of code that evaluates an object (or expression) for expected results. For example, an assertion can check:

* does this value = that value?
* is this object nil?
* does this line of code throw an exception?
* is the user's password greater than 5 characters?

Every test must contain at least one assertion, with no restriction as to how many assertions are allowed. Only when all the assertions are successful will the test pass.

### Maintaining the test database schema

In order to run your tests, your test database will need to have the current
structure. The test helper checks whether your test database has any pending
migrations. If so, it will try to load your `db/schema.rb` or `db/structure.sql`
into the test database. If migrations are still pending, an error will be
raised. Usually this indicates that your schema is not fully migrated. Running
the migrations against the development database (`bin/rake db:migrate`) will
bring the schema up to date.

NOTE: If existing migrations required modifications, the test database needs to
be rebuilt. This can be done by executing `bin/rake db:test:prepare`.

### Running Tests

Running a test is as simple as invoking the file containing the test cases through `rake test` command.

```bash
$ bin/rake test test/models/article_test.rb
.

Finished tests in 0.009262s, 107.9680 tests/s, 107.9680 assertions/s.

1 tests, 1 assertions, 0 failures, 0 errors, 0 skips
```

You can also run a particular test method from the test case by running the test and providing the `test method name`.

```bash
$ bin/rake test test/models/article_test.rb test_the_truth
.

Finished tests in 0.009064s, 110.3266 tests/s, 110.3266 assertions/s.

1 tests, 1 assertions, 0 failures, 0 errors, 0 skips
```

This will run all test methods from the test case.

The `.` (dot) above indicates a passing test. When a test fails you see an `F`; when a test throws an error you see an `E` in its place. The last line of the output is the summary.

#### Your first failing test

To see how a test failure is reported, you can add a failing test to the `article_test.rb` test case.

```ruby
test "should not save article without title" do
  article = Article.new
  assert_not article.save
end
```

Let us run this newly added test.

```bash
$ bin/rake test test/models/article_test.rb test_should_not_save_article_without_title
F

Finished tests in 0.044632s, 22.4054 tests/s, 22.4054 assertions/s.

  1) Failure:
test_should_not_save_article_without_title(ArticleTest) [test/models/article_test.rb:6]:
Failed assertion, no message given.

1 tests, 1 assertions, 1 failures, 0 errors, 0 skips
```

In the output, `F` denotes a failure. You can see the corresponding trace shown under `1)` along with the name of the failing test. The next few lines contain the stack trace followed by a message which mentions the actual value and the expected value by the assertion. The default assertion messages provide just enough information to help pinpoint the error. To make the assertion failure message more readable, every assertion provides an optional message parameter, as shown here:

```ruby
test "should not save article without title" do
  article = Article.new
  assert_not article.save, "Saved the article without a title"
end
```

Running this test shows the friendlier assertion message:

```bash
  1) Failure:
test_should_not_save_article_without_title(ArticleTest) [test/models/article_test.rb:6]:
Saved the article without a title
```

Now to get this test to pass we can add a model level validation for the _title_ field.

```ruby
class Article < ActiveRecord::Base
  validates :title, presence: true
end
```

Now the test should pass. Let us verify by running the test again:

```bash
$ bin/rake test test/models/article_test.rb test_should_not_save_article_without_title
.

Finished tests in 0.047721s, 20.9551 tests/s, 20.9551 assertions/s.

1 tests, 1 assertions, 0 failures, 0 errors, 0 skips
```

Now, if you noticed, we first wrote a test which fails for a desired functionality, then we wrote some code which adds the functionality and finally we ensured that our test passes. This approach to software development is referred to as _Test-Driven Development_ (TDD).

#### What an error looks like

To see how an error gets reported, here's a test containing an error:

```ruby
test "should report error" do
  # some_undefined_variable is not defined elsewhere in the test case
  some_undefined_variable
  assert true
end
```

Now you can see even more output in the console from running the tests:

```bash
$ bin/rake test test/models/article_test.rb test_should_report_error
E

Finished tests in 0.030974s, 32.2851 tests/s, 0.0000 assertions/s.

  1) Error:
test_should_report_error(ArticleTest):
NameError: undefined local variable or method `some_undefined_variable' for #<ArticleTest:0x007fe32e24afe0>
    test/models/article_test.rb:10:in `block in <class:ArticleTest>'

1 tests, 0 assertions, 0 failures, 1 errors, 0 skips
```

Notice the 'E' in the output. It denotes a test with error.

NOTE: The execution of each test method stops as soon as any error or an assertion failure is encountered, and the test suite continues with the next method. All test methods are executed in alphabetical order.

When a test fails you are presented with the corresponding backtrace. By default
Rails filters that backtrace and will only print lines relevant to your
application. This eliminates the framework noise and helps to focus on your
code. However there are situations when you want to see the full
backtrace. simply set the `BACKTRACE` environment variable to enable this
behavior:

```bash
$ BACKTRACE=1 bin/rake test test/models/article_test.rb
```

If we want this test to pass we can modify it to use `assert_raises` like so:

```ruby
test "should report error" do
  # some_undefined_variable is not defined elsewhere in the test case
  assert_raises(NameError) do
    some_undefined_variable
  end
end
```

This test should now pass.

### Available Assertions

By now you've caught a glimpse of some of the assertions that are available. Assertions are the worker bees of testing. They are the ones that actually perform the checks to ensure that things are going as planned.

There are a bunch of different types of assertions you can use that come with [`Minitest`](https://github.com/seattlerb/minitest), the default testing library used by Rails.

For a list of all available assertions please check the [Minitest API documentation](http://docs.seattlerb.org/minitest/), specifically [`Minitest::Assertions`](http://docs.seattlerb.org/minitest/Minitest/Assertions.html)

Because of the modular nature of the testing framework, it is possible to create your own assertions. In fact, that's exactly what Rails does. It includes some specialized assertions to make your life easier.

NOTE: Creating your own assertions is an advanced topic that we won't cover in this tutorial.

### Rails Specific Assertions

Rails adds some custom assertions of its own to the `minitest` framework:

| Assertion                                                                         | Purpose |
| --------------------------------------------------------------------------------- | ------- |
| `assert_difference(expressions, difference = 1, message = nil) {...}`             | Test numeric difference between the return value of an expression as a result of what is evaluated in the yielded block.|
| `assert_no_difference(expressions, message = nil, &amp;block)`                    | Asserts that the numeric result of evaluating an expression is not changed before and after invoking the passed in block.|
| `assert_recognizes(expected_options, path, extras={}, message=nil)`               | Asserts that the routing of the given path was handled correctly and that the parsed options (given in the expected_options hash) match path. Basically, it asserts that Rails recognizes the route given by expected_options.|
| `assert_generates(expected_path, options, defaults={}, extras = {}, message=nil)` | Asserts that the provided options can be used to generate the provided path. This is the inverse of assert_recognizes. The extras parameter is used to tell the request the names and values of additional request parameters that would be in a query string. The message parameter allows you to specify a custom error message for assertion failures.|
| `assert_response(type, message = nil)`                                            | Asserts that the response comes with a specific status code. You can specify `:success` to indicate 200-299, `:redirect` to indicate 300-399, `:missing` to indicate 404, or `:error` to match the 500-599 range. You can also pass an explicit status number or its symbolic equivalent. For more information, see [full list of status codes](http://rubydoc.info/github/rack/rack/master/Rack/Utils#HTTP_STATUS_CODES-constant) and how their [mapping](http://rubydoc.info/github/rack/rack/master/Rack/Utils#SYMBOL_TO_STATUS_CODE-constant) works.|
| `assert_redirected_to(options = {}, message=nil)`                                 | Assert that the redirection options passed in match those of the redirect called in the latest action. This match can be partial, such that `assert_redirected_to(controller: "weblog")` will also match the redirection of `redirect_to(controller: "weblog", action: "show")` and so on. You can also pass named routes such as `assert_redirected_to root_path` and Active Record objects such as `assert_redirected_to @article`.|
| `assert_template(expected = nil, message=nil)`                                    | Asserts that the request was rendered with the appropriate template file.|

You'll see the usage of some of these assertions in the next chapter.

### A Brief Note About Minitest

All the basic assertions such as `assert_equal` defined in `Minitest::Assertions` are also available in the classes we use in our own test cases. In fact, Rails provides the following classes for you to inherit from:

* `ActiveSupport::TestCase`
* `ActionController::TestCase`
* `ActionMailer::TestCase`
* `ActionView::TestCase`
* `ActionDispatch::IntegrationTest`

Each of these classes include `Minitest::Assertions`, allowing us to use all of the basic assertions in our tests.

NOTE: For more information on `Minitest`, refer to [Minitest](http://ruby-doc.org/stdlib-2.1.0/libdoc/minitest/rdoc/MiniTest.html)

Functional Tests for Your Controllers
-------------------------------------

In Rails, testing the various actions of a controller is a form of writing functional tests. Remember your controllers handle the incoming web requests to your application and eventually respond with a rendered view. When writing functional tests, you're testing how your actions handle the requests and the expected result, or response in some cases an HTML view.

### What to Include in your Functional Tests

You should test for things such as:

* was the web request successful?
* was the user redirected to the right page?
* was the user successfully authenticated?
* was the correct object stored in the response template?
* was the appropriate message displayed to the user in the view?

Now that we have used Rails scaffold generator for our `Article` resource, it has already created the controller code and tests. You can take look at the file `articles_controller_test.rb` in the `test/controllers` directory.

Let me take you through one such test, `test_should_get_index` from the file `articles_controller_test.rb`.

```ruby
class ArticlesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:articles)
  end
end
```

In the `test_should_get_index` test, Rails simulates a request on the action called `index`, making sure the request was successful and also ensuring that it assigns a valid `articles` instance variable.

The `get` method kicks off the web request and populates the results into the response. It accepts 4 arguments:

* The action of the controller you are requesting. This can be in the form of a string or a symbol.
* An optional hash of request parameters to pass into the action (eg. query string parameters or article variables).
* An optional hash of session variables to pass along with the request.
* An optional hash of flash values.

Example: Calling the `:show` action, passing an `id` of 12 as the `params` and setting a `user_id` of 5 in the session:

```ruby
get(:show, {'id' => "12"}, {'user_id' => 5})
```

Another example: Calling the `:view` action, passing an `id` of 12 as the `params`, this time with no session, but with a flash message.

```ruby
get(:view, {'id' => '12'}, nil, {'message' => 'booya!'})
```

NOTE: If you try running `test_should_create_article` test from `articles_controller_test.rb` it will fail on account of the newly added model level validation and rightly so.

Let us modify `test_should_create_article` test in `articles_controller_test.rb` so that all our test pass:

```ruby
test "should create article" do
  assert_difference('Article.count') do
    post :create, article: {title: 'Some title'}
  end

  assert_redirected_to article_path(assigns(:article))
end
```

Now you can try running all the tests and they should pass.

### Available Request Types for Functional Tests

If you're familiar with the HTTP protocol, you'll know that `get` is a type of request. There are 6 request types supported in Rails functional tests:

* `get`
* `post`
* `patch`
* `put`
* `head`
* `delete`

All of request types have equivalent methods that you can use. In a typical C.R.U.D. application you'll be using `get`, `post`, `put` and `delete` more often.

NOTE: Functional tests do not verify whether the specified request type is accepted by the action, we're more concerned with the result. Request tests exist for this use case to make your tests more purposeful.

### The Four Hashes of the Apocalypse

After a request has been made and processed, you will have 4 Hash objects ready for use:

* `assigns` - Any objects that are stored as instance variables in actions for use in views.
* `cookies` - Any cookies that are set.
* `flash` - Any objects living in the flash.
* `session` - Any object living in session variables.

As is the case with normal Hash objects, you can access the values by referencing the keys by string. You can also reference them by symbol name, except for `assigns`. For example:

```ruby
flash["gordon"]               flash[:gordon]
session["shmession"]          session[:shmession]
cookies["are_good_for_u"]     cookies[:are_good_for_u]

# Because you can't use assigns[:something] for historical reasons:
assigns["something"]          assigns(:something)
```

### Instance Variables Available

You also have access to three instance variables in your functional tests:

* `@controller` - The controller processing the request
* `@request` - The request object
* `@response` - The response object

### Setting Headers and CGI variables

[HTTP headers](http://tools.ietf.org/search/rfc2616#section-5.3)
and
[CGI variables](http://tools.ietf.org/search/rfc3875#section-4.1)
can be set directly on the `@request` instance variable:

```ruby
# setting a HTTP Header
@request.headers["Accept"] = "text/plain, text/html"
get :index # simulate the request with custom header

# setting a CGI variable
@request.headers["HTTP_REFERER"] = "http://example.com/home"
post :create # simulate the request with custom env variable
```

### Testing Templates and Layouts

Eventually, you may want to test whether a specific layout is rendered in the view of a response.

#### Asserting Templates

If you want to make sure that the response rendered the correct template and layout, you can use the `assert_template`
method:

```ruby
test "index should render correct template and layout" do
  get :index
  assert_template :index
  assert_template layout: "layouts/application"

  # You can also pass a regular expression.
  assert_template layout: /layouts\/application/
end
```

NOTE: You cannot test for template and layout at the same time, with a single call to `assert_template`.

WARNING: You must include the "layouts" directory name even if you save your layout file in this standard layout directory. Hence, `assert_template layout: "application"` will not work.

#### Asserting Partials

If your view renders any partial, when asserting for the layout, you can to assert for the partial at the same time.
Otherwise, assertion will fail.

Remember, we added the "_form" partial to our creating Articles view? Let's write an assertion for that in the `:new` action now:

```ruby
test "new should render correct layout" do
  get :new
  assert_template layout: "layouts/application", partial: "_form"
end
```

This is the correct way to assert for when the view renders a partial with a given name. As identified by the `:partial` key passed to the `assert_template` call.

### Testing `flash` notices

If you remember from earlier one of the Four Hashes of the Apocalypse was `flash`.

We want to add a `flash` message to our blog application whenever someone
successfully creates a new Article.

Let's start by adding this assertion to our `test_should_create_article` test:

```ruby
test "should create article" do
  assert_difference('Article.count') do
    post :create, article: {title: 'Some title'}
  end

  assert_redirected_to article_path(assigns(:article))
  assert_equal 'Article was successfully created.', flash[:notice]
end
```

If we run our test now, we should see a failure:

```bash
$ bin/rake test test/controllers/articles_controller_test.rb test_should_create_article
Run options: -n test_should_create_article --seed 32266

# Running:

F

Finished in 0.114870s, 8.7055 runs/s, 34.8220 assertions/s.

  1) Failure:
ArticlesControllerTest#test_should_create_article [/Users/zzak/code/bench/sharedapp/test/controllers/articles_controller_test.rb:16]:
--- expected
+++ actual
@@ -1 +1 @@
-"Article was successfully created."
+nil

1 runs, 4 assertions, 1 failures, 0 errors, 0 skips
```

Let's implement the flash message now in our controller. Our `:create` action should now look like this:

```ruby
def create
  @article = Article.new(article_params)

  if @article.save
    flash[:notice] = 'Article was successfully created.'
    redirect_to @article
  else
    render 'new'
  end
end
```

Now if we run our tests, we should see it pass:

```bash
$ bin/rake test test/controllers/articles_controller_test.rb test_should_create_article
Run options: -n test_should_create_article --seed 18981

# Running:

.

Finished in 0.081972s, 12.1993 runs/s, 48.7972 assertions/s.

1 runs, 4 assertions, 0 failures, 0 errors, 0 skips
```

### Putting it together

At this point our Articles controller tests the `:index` as well as `:new` and `:create` actions. What about dealing with existing data?

Let's write a test for the `:show` action:

```ruby
test "should show article" do
  article = articles(:one)
  get :show, id: article.id
  assert_response :success
end
```

Remember from our discussion earlier on fixtures the `articles()` method will give us access to our Articles fixtures.

How about deleting an existing Article?

```ruby
test "should destroy article" do
  article = articles(:one)
  assert_difference('Article.count', -1) do
    delete :destroy, id: article.id
  end

  assert_redirected_to articles_path
end
```

We can also add a test for updating an existing Article.

```ruby
test "should update article" do
  article = articles(:one)
  patch :update, id: article.id, article: {title: "updated"}
  assert_redirected_to article_path(assigns(:article))
end
```

Notice we're starting to see some duplication in these three tests, they both access the same Article fixture data. We can D.R.Y. this up by using the `setup` and `teardown` methods provided by `ActiveSupport::Callbacks`.

Our test should now look something like this, disregard the other tests we're leaving them out for brevity.

```ruby
require 'test_helper'

class ArticlesControllerTest < ActionController::TestCase
  # called before every single test
  def setup
    @article = articles(:one)
  end

  # called after every single test
  def teardown
    # as we are re-initializing @article before every test
    # setting it to nil here is not essential but I hope
    # you understand how you can use the teardown method
    @article = nil
  end

  test "should show article" do
    # Reuse the @article instance variable from setup
    get :show, id: @article.id
    assert_response :success
  end

  test "should destroy article" do
    assert_difference('Article.count', -1) do
      delete :destroy, id: @article.id
    end

    assert_redirected_to articles_path
  end

  test "should update article" do
    patch :update, id: @article.id, article: {title: "updated"}
    assert_redirected_to article_path(assigns(:article))
  end
end
```

Similar to other callbacks in Rails, the `setup` and `teardown` methods can also be used by passing a block, lambda, or method name as a symbol to call.

Testing Routes
--------------

Like everything else in your Rails application, it is recommended that you test your routes. Below are example tests for the routes of default `show` and `create` action of `Articles` controller above and it should look like:

```ruby
class ArticleRoutesTest < ActionController::TestCase
  test "should route to article" do
    assert_routing '/articles/1', { controller: "articles", action: "show", id: "1" }
  end

  test "should route to create article" do
    assert_routing({ method: 'post', path: '/articles' }, { controller: "articles", action: "create" })
  end
end
```

I've added this file here `test/controllers/articles_routes_test.rb` and if we run the test we should see:

```bash
$ bin/rake test test/controllers/articles_routes_test.rb

# Running:

..

Finished in 0.069381s, 28.8263 runs/s, 86.4790 assertions/s.

2 runs, 6 assertions, 0 failures, 0 errors, 0 skips
```

For more information on routing assertions available in Rails, see the API documentation for [`ActionDispatch::Assertions::RoutingAssertions`](http://api.rubyonrails.org/classes/ActionDispatch/Assertions/RoutingAssertions.html).

Testing Views
-------------

Testing the response to your request by asserting the presence of key HTML elements and their content is a common way to test the views of your application. The `assert_select` method allows you to query HTML elements of the response by using a simple yet powerful syntax.

There are two forms of `assert_select`:

`assert_select(selector, [equality], [message])` ensures that the equality condition is met on the selected elements through the selector. The selector may be a CSS selector expression (String) or an expression with substitution values.

`assert_select(element, selector, [equality], [message])` ensures that the equality condition is met on all the selected elements through the selector starting from the _element_ (instance of `Nokogiri::XML::Node` or `Nokogiri::XML::NodeSet`) and its descendants.

For example, you could verify the contents on the title element in your response with:

```ruby
assert_select 'title', "Welcome to Rails Testing Guide"
```

You can also use nested `assert_select` blocks for deeper investigation.

In the following example, the inner `assert_select` for `li.menu_item` runs
within the collection of elements selected by the outer block:

```ruby
assert_select 'ul.navigation' do
  assert_select 'li.menu_item'
end
```

A collection of selected elements may be iterated through so that `assert_select` may be called separately for each element.

For example if the response contains two ordered lists, each with four nested list elements then the following tests will both pass.

```ruby
assert_select "ol" do |elements|
  elements.each do |element|
    assert_select element, "li", 4
  end
end

assert_select "ol" do
  assert_select "li", 8
end
```

This assertion is quite powerful. For more advanced usage, refer to its [documentation](http://www.rubydoc.info/github/rails/rails-dom-testing).

#### Additional View-Based Assertions

There are more assertions that are primarily used in testing views:

| Assertion                                                 | Purpose |
| --------------------------------------------------------- | ------- |
| `assert_select_email`                                     | Allows you to make assertions on the body of an e-mail. |
| `assert_select_encoded`                                   | Allows you to make assertions on encoded HTML. It does this by un-encoding the contents of each element and then calling the block with all the un-encoded elements.|
| `css_select(selector)` or `css_select(element, selector)` | Returns an array of all the elements selected by the _selector_. In the second variant it first matches the base _element_ and tries to match the _selector_ expression on any of its children. If there are no matches both variants return an empty array.|

Here's an example of using `assert_select_email`:

```ruby
assert_select_email do
  assert_select 'small', 'Please click the "Unsubscribe" link if you want to opt-out.'
end
```

Testing helpers
---------------

In order to test helpers, all you need to do is check that the output of the
helper method matches what you'd expect. Tests related to the helpers are
located under the `test/helpers` directory.

A helper test looks like so:

```ruby
require 'test_helper'

class UserHelperTest < ActionView::TestCase
end
```

A helper is just a simple module where you can define methods which are
available into your views. To test the output of the helper's methods, you just
have to use a mixin like this:

```ruby
class UserHelperTest < ActionView::TestCase
  include UserHelper

  test "should return the user name" do
    # ...
  end
end
```

Moreover, since the test class extends from `ActionView::TestCase`, you have
access to Rails' helper methods such as `link_to` or `pluralize`.

Integration Testing
-------------------

Integration tests are used to test how various parts of your application interact. They are generally used to test important work flows within your application.

For creating Rails integration tests, we use the 'test/integration' directory for your application. Rails provides a generator to create an integration test skeleton for you.

```bash
$ bin/rails generate integration_test user_flows
      exists  test/integration/
      create  test/integration/user_flows_test.rb
```

Here's what a freshly-generated integration test looks like:

```ruby
require 'test_helper'

class UserFlowsTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end
end
```

Inheriting from `ActionDispatch::IntegrationTest` comes with some advantages. This makes available some additional helpers to use in your integration tests.

### Helpers Available for Integration Tests

In addition to the standard testing helpers, inheriting `ActionDispatch::IntegrationTest` comes with some additional helpers available when writing integration tests. Let's briefly introduce you to the three categories of helpers you get to choose from.

For dealing with the integration test runner, see [`ActionDispatch::Integration::Runner`](http://api.rubyonrails.org/classes/ActionDispatch/Integration/Runner.html).

When performing requests, you will have [`ActionDispatch::Integration::RequestHelpers`](http://api.rubyonrails.org/classes/ActionDispatch/Integration/RequestHelpers.html) available for your use.

If you'd like to modify the session, or state of your integration test you should look for [`ActionDispatch::Integration::Session`](http://api.rubyonrails.org/classes/ActionDispatch/Integration/Session.html) to help.

### Implementing an integration test

Let's add an integration test to our blog application. We'll start with a basic workflow of creating a new blog article, to verify that everything is working properly.

We'll start by generating our integration test skeleton:

```bash
$ bin/rails generate integration_test blog_flow
```

It should have created a test file placeholder for us, with the output of the previous command you should see:

```bash
      invoke  test_unit
      create    test/integration/blog_flow_test.rb
```

Now let's open that file and write our first assertion:

```ruby
require 'test_helper'

class BlogFlowTest < ActionDispatch::IntegrationTest
  test "can see the welcome page" do
    get "/"
    assert_select "h1", "Welcome#index"
  end
end
```

If you remember from earlier in the "Testing Views" section we covered `assert_select` to query the resulting HTML of a request.

When visit our root path, we should see `welcome/index.html.erb` rendered for the view. So this assertion should pass.

#### Creating articles integration

How about testing our ability to create a new article in our blog and see the resulting article.

```ruby
test "can create an article" do
  get "/articles/new"
  assert_response :success
  assert_template "articles/new", partial: "articles/_form"

  post "/articles", article: {title: "can create", body: "article successfully."}
  assert_response :redirect
  follow_redirect!
  assert_response :success
  assert_template "articles/show"
  assert_select "p", "Title:\n  can create"
end
```

Let's break this test down so we can understand it.

We start by calling the `:new` action on our Articles controller. This response should be successful, and we can verify the correct template is rendered including the form partial.

After this we make a post request to the `:create` action of our Articles controller:

```ruby
post "/articles", article: {title: "can create", body: "article successfully."}
assert_response :redirect
follow_redirect!
```

The two lines following the request are to handle the redirect we setup when creating a new article.

NOTE: Don't forget to call `follow_redirect!` if you plan to make subsequent requests after a redirect is made.

Finally we can assert that our response was successful, template was rendered, and our new article is readable on the page.

#### Taking it further

We were able to successfully test a very small workflow for visiting our blog and creating a new article. If we wanted to take this further we could add tests for commenting, removing articles, or editting comments. Integration tests are a great place to experiment with all kinds of use-cases for our applications.

Testing Your Mailers
--------------------

Testing mailer classes requires some specific tools to do a thorough job.

### Keeping the Postman in Check

Your mailer classes - like every other part of your Rails application - should be tested to ensure that it is working as expected.

The goals of testing your mailer classes are to ensure that:

* emails are being processed (created and sent)
* the email content is correct (subject, sender, body, etc)
* the right emails are being sent at the right times

#### From All Sides

There are two aspects of testing your mailer, the unit tests and the functional tests. In the unit tests, you run the mailer in isolation with tightly controlled inputs and compare the output to a known value (a fixture.) In the functional tests you don't so much test the minute details produced by the mailer; instead, we test that our controllers and models are using the mailer in the right way. You test to prove that the right email was sent at the right time.

### Unit Testing

In order to test that your mailer is working as expected, you can use unit tests to compare the actual results of the mailer with pre-written examples of what should be produced.

#### Revenge of the Fixtures

For the purposes of unit testing a mailer, fixtures are used to provide an example of how the output _should_ look. Because these are example emails, and not Active Record data like the other fixtures, they are kept in their own subdirectory apart from the other fixtures. The name of the directory within `test/fixtures` directly corresponds to the name of the mailer. So, for a mailer named `UserMailer`, the fixtures should reside in `test/fixtures/user_mailer` directory.

When you generated your mailer, the generator creates stub fixtures for each of the mailers actions. If you didn't use the generator you'll have to make those files yourself.

#### The Basic Test Case

Here's a unit test to test a mailer named `UserMailer` whose action `invite` is used to send an invitation to a friend. It is an adapted version of the base test created by the generator for an `invite` action.

```ruby
require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  test "invite" do
    # Send the email, then test that it got queued
    email = UserMailer.create_invite('me@example.com',
                                     'friend@example.com', Time.now).deliver_now
    assert_not ActionMailer::Base.deliveries.empty?

    # Test the body of the sent email contains what we expect it to
    assert_equal ['me@example.com'], email.from
    assert_equal ['friend@example.com'], email.to
    assert_equal 'You have been invited by me@example.com', email.subject
    assert_equal read_fixture('invite').join, email.body.to_s
  end
end
```

In the test we send the email and store the returned object in the `email`
variable. We then ensure that it was sent (the first assert), then, in the
second batch of assertions, we ensure that the email does indeed contain what we
expect. The helper `read_fixture` is used to read in the content from this file.

Here's the content of the `invite` fixture:

```
Hi friend@example.com,

You have been invited.

Cheers!
```

This is the right time to understand a little more about writing tests for your
mailers. The line `ActionMailer::Base.delivery_method = :test` in
`config/environments/test.rb` sets the delivery method to test mode so that
email will not actually be delivered (useful to avoid spamming your users while
testing) but instead it will be appended to an array
(`ActionMailer::Base.deliveries`).

NOTE: The `ActionMailer::Base.deliveries` array is only reset automatically in
`ActionMailer::TestCase` tests. If you want to have a clean slate outside Action
Mailer tests, you can reset it manually with:
`ActionMailer::Base.deliveries.clear`

### Functional Testing

Functional testing for mailers involves more than just checking that the email body, recipients and so forth are correct. In functional mail tests you call the mail deliver methods and check that the appropriate emails have been appended to the delivery list. It is fairly safe to assume that the deliver methods themselves do their job. You are probably more interested in whether your own business logic is sending emails when you expect them to go out. For example, you can check that the invite friend operation is sending an email appropriately:

```ruby
require 'test_helper'

class UserControllerTest < ActionController::TestCase
  test "invite friend" do
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      post :invite_friend, email: 'friend@example.com'
    end
    invite_email = ActionMailer::Base.deliveries.last

    assert_equal "You have been invited by me@example.com", invite_email.subject
    assert_equal 'friend@example.com', invite_email.to[0]
    assert_match(/Hi friend@example.com/, invite_email.body.to_s)
  end
end
```

Testing Jobs
------------

Since your custom jobs can be queued at different levels inside your application,
you'll need to test both jobs themselves (their behavior when they get enqueued)
and that other entities correctly enqueue them.

### A Basic Test Case

By default, when you generate a job, an associated test will be generated as well
under the `test/jobs` directory. Here's an example test with a billing job:

```ruby
require 'test_helper'

class BillingJobTest < ActiveJob::TestCase
  test 'that account is charged' do
    BillingJob.perform_now(account, product)
    assert account.reload.charged_for?(product)
  end
end
```

This test is pretty simple and only asserts that the job get the work done
as expected.

By default, `ActiveJob::TestCase` will set the queue adapter to `:test` so that
your jobs are performed inline. It will also ensure that all previously performed
and enqueued jobs are cleared before any test run so you can safely assume that
no jobs have already been executed in the scope of each test.

### Custom Assertions And Testing Jobs Inside Other Components

Active Job ships with a bunch of custom assertions that can be used to lessen the verbosity of tests. For a full list of available assertions, see the API documentation for [`ActiveJob::TestHelper`](http://api.rubyonrails.org/classes/ActiveJob/TestHelper.html).

It's a good practice to ensure that your jobs correctly get enqueued or performed
wherever you invoke them (e.g. inside your controllers). This is precisely where
the custom assertions provided by Active Job are pretty useful. For instance,
within a model:

```ruby
require 'test_helper'

class ProductTest < ActiveSupport::TestCase
  test 'billing job scheduling' do
    assert_enqueued_with(job: BillingJob) do
      product.charge(account)
    end
  end
end
```

Other Testing Approaches
------------------------

The built-in `minitest` based testing is not the only way to test Rails applications. Rails developers have come up with a wide variety of other approaches and aids for testing, including:

* [NullDB](http://avdi.org/projects/nulldb/), a way to speed up testing by avoiding database use.
* [Factory Girl](https://github.com/thoughtbot/factory_girl/tree/master), a replacement for fixtures.
* [Fixture Builder](https://github.com/rdy/fixture_builder), a tool that compiles Ruby factories into fixtures before a test run.
* [MiniTest::Spec Rails](https://github.com/metaskills/minitest-spec-rails), use the MiniTest::Spec DSL within your rails tests.
* [Shoulda](http://www.thoughtbot.com/projects/shoulda), an extension to `test/unit` with additional helpers, macros, and assertions.
* [RSpec](http://relishapp.com/rspec), a behavior-driven development framework
* [Capybara](http://jnicklas.github.com/capybara/), Acceptance test framework for web applications
