**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Autoloading and Reloading Constants (Classic Mode)
==================================================

This guide documents how constant autoloading and reloading works in `classic` mode.

After reading this guide, you will know:

* Key aspects of Ruby constants
* What the `autoload_paths` are and how eager loading works in production
* How constant autoloading works
* What `require_dependency` is
* How constant reloading works
* Solutions to common autoloading gotchas

--------------------------------------------------------------------------------

Introduction
------------

INFO. This guide documents autoloading in `classic` mode, which is the traditional one. If you'd like to read about `zeitwerk` mode instead, the new one in Rails 6, please check [Autoloading and Reloading Constants (Zeitwerk Mode)](autoloading_and_reloading_constants.html).

Ruby on Rails allows applications to be written as if their code was preloaded.

In a normal Ruby program classes need to load their dependencies:

```ruby
require "application_controller"
require "post"

class PostsController < ApplicationController
  def index
    @posts = Post.all
  end
end
```

Our Rubyist instinct quickly sees some redundancy in there: If classes were
defined in files matching their name, couldn't their loading be automated
somehow? We could save scanning the file for dependencies, which is brittle.

Moreover, `Kernel#require` loads files once, but development is much more smooth
if code gets refreshed when it changes without restarting the server. It would
be nice to be able to use `Kernel#load` in development, and `Kernel#require` in
production.

Indeed, those features are provided by Ruby on Rails, where we just write

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.all
  end
end
```

This guide documents how that works.


Constants Refresher
-------------------

While constants are trivial in most programming languages, they are a rich
topic in Ruby.

It is beyond the scope of this guide to document Ruby constants, but we are
nevertheless going to highlight a few key topics. Truly grasping the following
sections is instrumental to understanding constant autoloading and reloading.

### Nesting

Class and module definitions can be nested to create namespaces:

```ruby
module XML
  class SAXParser
    # (1)
  end
end
```

The *nesting* at any given place is the collection of enclosing nested class and
module objects outwards. The nesting at any given place can be inspected with
`Module.nesting`. For example, in the previous example, the nesting at
(1) is

```ruby
[XML::SAXParser, XML]
```

It is important to understand that the nesting is composed of class and module
*objects*, it has nothing to do with the constants used to access them, and is
also unrelated to their names.

For instance, while this definition is similar to the previous one:

```ruby
class XML::SAXParser
  # (2)
end
```

the nesting in (2) is different:

```ruby
[XML::SAXParser]
```

`XML` does not belong to it.

We can see in this example that the name of a class or module that belongs to a
certain nesting does not necessarily correlate with the namespaces at the spot.

Even more, they are totally independent, take for instance

```ruby
module X
  module Y
  end
end

module A
  module B
  end
end

module X::Y
  module A::B
    # (3)
  end
end
```

The nesting in (3) consists of two module objects:

```ruby
[A::B, X::Y]
```

So, it not only doesn't end in `A`, which does not even belong to the nesting,
but it also contains `X::Y`, which is independent from `A::B`.

The nesting is an internal stack maintained by the interpreter, and it gets
modified according to these rules:

* The class object following a `class` keyword gets pushed when its body is
executed, and popped after it.

* The module object following a `module` keyword gets pushed when its body is
executed, and popped after it.

* A singleton class opened with `class << object` gets pushed, and popped later.

* When `instance_eval` is called using a string argument,
the singleton class of the receiver is pushed to the nesting of the eval'ed
code. When `class_eval` or `module_eval` is called using a string argument,
the receiver is pushed to the nesting of the eval'ed code.

* The nesting at the top-level of code interpreted by `Kernel#load` is empty
unless the `load` call receives a true value as second argument, in which case
a newly created anonymous module is pushed by Ruby.

It is interesting to observe that blocks do not modify the stack. In particular
the blocks that may be passed to `Class.new` and `Module.new` do not get the
class or module being defined pushed to their nesting. That's one of the
differences between defining classes and modules in one way or another.

### Class and Module Definitions are Constant Assignments

Let's suppose the following snippet creates a class (rather than reopening it):

```ruby
class C
end
```

Ruby creates a constant `C` in `Object` and stores in that constant a class
object. The name of the class instance is "C", a string, named after the
constant.

That is,

```ruby
class Project < ApplicationRecord
end
```

performs a constant assignment equivalent to

```ruby
Project = Class.new(ApplicationRecord)
```

including setting the name of the class as a side-effect:

```ruby
Project.name # => "Project"
```

Constant assignment has a special rule to make that happen: if the object
being assigned is an anonymous class or module, Ruby sets the object's name to
the name of the constant.

INFO. From then on, what happens to the constant and the instance does not
matter. For example, the constant could be deleted, the class object could be
assigned to a different constant, be stored in no constant anymore, etc. Once
the name is set, it doesn't change.

Similarly, module creation using the `module` keyword as in

```ruby
module Admin
end
```

performs a constant assignment equivalent to

```ruby
Admin = Module.new
```

including setting the name as a side-effect:

```ruby
Admin.name # => "Admin"
```

WARNING. The execution context of a block passed to `Class.new` or `Module.new`
is not entirely equivalent to the one of the body of the definitions using the
`class` and `module` keywords. But both idioms result in the same constant
assignment.

Thus, an informal expression like "the `String` class" technically means the
class object stored in the constant called "String". That constant, in turn,
belongs to the class object stored in the constant called "Object".

`String` is an ordinary constant, and everything related to them such as
resolution algorithms applies to it.

Likewise, in the controller

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.all
  end
end
```

`Post` is not syntax for a class. Rather, `Post` is a regular Ruby constant. If
all is good, the constant is evaluated to an object that responds to `all`.

That is why we talk about *constant* autoloading, Rails has the ability to
load constants on the fly.

### Constants are Stored in Modules

Constants belong to modules in a very literal sense. Classes and modules have
a constant table; think of it as a hash table.

Let's analyze an example to really understand what that means. While common
abuses of language like "the `String` class" are convenient, the exposition is
going to be precise here for didactic purposes.

Let's consider the following module definition:

```ruby
module Colors
  RED = '0xff0000'
end
```

First, when the `module` keyword is processed, the interpreter creates a new
entry in the constant table of the class object stored in the `Object` constant.
Said entry associates the name "Colors" to a newly created module object.
Furthermore, the interpreter sets the name of the new module object to be the
string "Colors".

Later, when the body of the module definition is interpreted, a new entry is
created in the constant table of the module object stored in the `Colors`
constant. That entry maps the name "RED" to the string "0xff0000".

In particular, `Colors::RED` is totally unrelated to any other `RED` constant
that may live in any other class or module object. If there were any, they
would have separate entries in their respective constant tables.

Pay special attention in the previous paragraphs to the distinction between
class and module objects, constant names, and value objects associated to them
in constant tables.

### Resolution Algorithms

#### Resolution Algorithm for Relative Constants

At any given place in the code, let's define *cref* to be the first element of
the nesting if it is not empty, or `Object` otherwise.

Without getting too much into the details, the resolution algorithm for relative
constant references goes like this:

1. If the nesting is not empty the constant is looked up in its elements and in
order. The ancestors of those elements are ignored.

2. If not found, then the algorithm walks up the ancestor chain of the cref.

3. If not found and the cref is a module, the constant is looked up in `Object`.

4. If not found, `const_missing` is invoked on the cref. The default
implementation of `const_missing` raises `NameError`, but it can be overridden.

Rails autoloading **does not emulate this algorithm**, but its starting point is
the name of the constant to be autoloaded, and the cref. See more in [Relative
References](#autoloading-algorithms-relative-references).

#### Resolution Algorithm for Qualified Constants

Qualified constants look like this:

```ruby
Billing::Invoice
```

`Billing::Invoice` is composed of two constants: `Billing` is relative and is
resolved using the algorithm of the previous section.

INFO. Leading colons would make the first segment absolute rather than
relative: `::Billing::Invoice`. That would force `Billing` to be looked up
only as a top-level constant.

`Invoice` on the other hand is qualified by `Billing` and we are going to see
its resolution next. Let's define *parent* to be that qualifying class or module
object, that is, `Billing` in the example above. The algorithm for qualified
constants goes like this:

1. The constant is looked up in the parent and its ancestors. In Ruby >= 2.5,
`Object` is skipped if present among the ancestors. `Kernel` and `BasicObject`
are still checked though.

2. If the lookup fails, `const_missing` is invoked in the parent. The default
implementation of `const_missing` raises `NameError`, but it can be overridden.

INFO. In Ruby < 2.5 `String::Hash` evaluates to `Hash` and the interpreter
issues a warning: "toplevel constant Hash referenced by String::Hash". Starting
with 2.5, `String::Hash` raises `NameError` because `Object` is skipped.

As you see, this algorithm is simpler than the one for relative constants. In
particular, the nesting plays no role here, and modules are not special-cased,
if neither they nor their ancestors have the constants, `Object` is **not**
checked.

Rails autoloading **does not emulate this algorithm**, but its starting point is
the name of the constant to be autoloaded, and the parent. See more in
[Qualified References](#autoloading-algorithms-qualified-references).


Vocabulary
----------

### Parent Namespaces

Given a string with a constant path we define its *parent namespace* to be the
string that results from removing its rightmost segment.

For example, the parent namespace of the string "A::B::C" is the string "A::B",
the parent namespace of "A::B" is "A", and the parent namespace of "A" is "".

The interpretation of a parent namespace when thinking about classes and modules
is tricky though. Let's consider a module M named "A::B":

* The parent namespace, "A", may not reflect nesting at a given spot.

* The constant `A` may no longer exist, some code could have removed it from
`Object`.

* If `A` exists, the class or module that was originally in `A` may not be there
anymore. For example, if after a constant removal there was another constant
assignment there would generally be a different object in there.

* In such case, it could even happen that the reassigned `A` held a new class or
module called also "A"!

* In the previous scenarios M would no longer be reachable through `A::B` but
the module object itself could still be alive somewhere and its name would
still be "A::B".

The idea of a parent namespace is at the core of the autoloading algorithms
and helps explain and understand their motivation intuitively, but as you see
that metaphor leaks easily. Given an edge case to reason about, take always into
account that by "parent namespace" the guide means exactly that specific string
derivation.

### Loading Mechanism

Rails autoloads files with `Kernel#load` when `config.cache_classes` is false,
the default in development mode, and with `Kernel#require` otherwise, the
default in production mode.

`Kernel#load` allows Rails to execute files more than once if [constant
reloading](#constant-reloading) is enabled.

This guide uses the word "load" freely to mean a given file is interpreted, but
the actual mechanism can be `Kernel#load` or `Kernel#require` depending on that
flag.


Autoloading Availability
------------------------

Rails is always able to autoload provided its environment is in place. For
example the `runner` command autoloads:

```bash
$ bin/rails runner 'p User.column_names'
["id", "email", "created_at", "updated_at"]
```

The console autoloads, the test suite autoloads, and of course the application
autoloads.

By default, Rails eager loads the application files when it boots in production
mode, so most of the autoloading going on in development does not happen. But
autoloading may still be triggered during eager loading.

For example, given

```ruby
class BeachHouse < House
end
```

if `House` is still unknown when `app/models/beach_house.rb` is being eager
loaded, Rails autoloads it.


autoload_paths and eager_load_paths
-----------------------------------

As you probably know, when `require` gets a relative file name:

```ruby
require "erb"
```

Ruby looks for the file in the directories listed in `$LOAD_PATH`. That is, Ruby
iterates over all its directories and for each one of them checks whether they
have a file called "erb.rb", or "erb.so", or "erb.o", or "erb.dll". If it finds
any of them, the interpreter loads it and ends the search. Otherwise, it tries
again in the next directory of the list. If the list gets exhausted, `LoadError`
is raised.

We are going to cover how constant autoloading works in more detail later, but
the idea is that when a constant like `Post` is hit and missing, if there's a
`post.rb` file for example in `app/models` Rails is going to find it, evaluate
it, and have `Post` defined as a side-effect.

All right, Rails has a collection of directories similar to `$LOAD_PATH` in which
to look up `post.rb`. That collection is called `autoload_paths` and by
default it contains:

* All subdirectories of `app` in the application and engines present at boot
  time. For example, `app/controllers`. They do not need to be the default
  ones, any custom directories like `app/workers` belong automatically to
  `autoload_paths`.

* Any existing second level directories called `app/*/concerns` in the
  application and engines.

* The directory `test/mailers/previews`.

`eager_load_paths` is initially the `app` paths above

How files are autoloaded depends on `eager_load` and `cache_classes` config settings which typically vary in development, production, and test modes:

* In **development**, you want quicker startup with incremental loading of application code. So `eager_load` should be set to `false`, and Rails will autoload files as needed (see [Autoloading Algorithms](#autoloading-algorithms) below) -- and then reload them when they change (see [Constant Reloading](#constant-reloading) below).
* In **production**, however, you want consistency and thread-safety and can live with a longer boot time. So `eager_load` is set to `true`, and then during boot (before the app is ready to receive requests) Rails loads all files in the `eager_load_paths` and then turns off auto loading (NB: autoloading may be needed during eager loading). Not autoloading after boot is a `good thing`, as autoloading can cause the app to have thread-safety problems.
* In **test**, for speed of execution (of individual tests) `eager_load` is `false`, so Rails follows development behaviour.

What is described above are the defaults with a newly generated Rails app.
There are multiple ways this can be configured differently (see [Configuring
Rails Applications](configuring.html#rails-general-configuration)). In the past, before
Rails 5, developers might configure `autoload_paths` to add in extra locations
(e.g. `lib` which used to be an autoload path list years ago, but no longer
is). However this is now discouraged for most purposes, as it is likely to
lead to production-only errors. It is possible to add new locations to both
`config.eager_load_paths` and `config.autoload_paths` but use at your own risk.

See also [Autoloading in the Test Environment](#autoloading-in-the-test-environment).

The value of `autoload_paths` can be inspected. In a just-generated application
it is (edited):

```bash
$ bin/rails runner 'puts ActiveSupport::Dependencies.autoload_paths'
.../app/assets
.../app/channels
.../app/controllers
.../app/controllers/concerns
.../app/helpers
.../app/jobs
.../app/mailers
.../app/models
.../app/models/concerns
.../activestorage/app/assets
.../activestorage/app/controllers
.../activestorage/app/javascript
.../activestorage/app/jobs
.../activestorage/app/models
.../actioncable/app/assets
.../actionview/app/assets
.../test/mailers/previews
```

INFO. `autoload_paths` is computed and cached during the initialization process.
The application needs to be restarted to reflect any changes in the directory
structure.


Autoloading Algorithms
----------------------

### Relative References

A relative constant reference may appear in several places, for example, in

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.all
  end
end
```

all three constant references are relative.

#### Constants after the `class` and `module` Keywords

Ruby performs a lookup for the constant that follows a `class` or `module`
keyword because it needs to know if the class or module is going to be created
or reopened.

If the constant is not defined at that point it is not considered to be a
missing constant, autoloading is **not** triggered.

So, in the previous example, if `PostsController` is not defined when the file
is interpreted Rails autoloading is not going to be triggered, Ruby will just
define the controller.

#### Top-Level Constants

On the contrary, if `ApplicationController` is unknown, the constant is
considered missing and an autoload is going to be attempted by Rails.

In order to load `ApplicationController`, Rails iterates over `autoload_paths`.
First it checks if `app/assets/application_controller.rb` exists. If it does not,
which is normally the case, it continues and finds
`app/controllers/application_controller.rb`.

If the file defines the constant `ApplicationController` all is fine, otherwise
`LoadError` is raised:

```
unable to autoload constant ApplicationController, expected
<full path to application_controller.rb> to define it (LoadError)
```

INFO. Rails does not require the value of autoloaded constants to be a class or
module object. For example, if the file `app/models/max_clients.rb` defines
`MAX_CLIENTS = 100` autoloading `MAX_CLIENTS` works just fine.

#### Namespaces

Autoloading `ApplicationController` looks directly under the directories of
`autoload_paths` because the nesting in that spot is empty. The situation of
`Post` is different, the nesting in that line is `[PostsController]` and support
for namespaces comes into play.

The basic idea is that given

```ruby
module Admin
  class BaseController < ApplicationController
    @@all_roles = Role.all
  end
end
```

to autoload `Role` we are going to check if it is defined in the current or
parent namespaces, one at a time. So, conceptually we want to try to autoload
any of

```
Admin::BaseController::Role
Admin::Role
Role
```

in that order. That's the idea. To do so, Rails looks in `autoload_paths`
respectively for file names like these:

```
admin/base_controller/role.rb
admin/role.rb
role.rb
```

modulus some additional directory lookups we are going to cover soon.

INFO. `'Constant::Name'.underscore` gives the relative path without extension of
the file name where `Constant::Name` is expected to be defined.

Let's see how Rails autoloads the `Post` constant in the `PostsController`
above assuming the application has a `Post` model defined in
`app/models/post.rb`.

First it checks for `posts_controller/post.rb` in `autoload_paths`:

```
app/assets/posts_controller/post.rb
app/controllers/posts_controller/post.rb
app/helpers/posts_controller/post.rb
...
test/mailers/previews/posts_controller/post.rb
```

Since the lookup is exhausted without success, a similar search for a directory
is performed, we are going to see why in the [next section](#automatic-modules):

```
app/assets/posts_controller/post
app/controllers/posts_controller/post
app/helpers/posts_controller/post
...
test/mailers/previews/posts_controller/post
```

If all those attempts fail, then Rails starts the lookup again in the parent
namespace. In this case only the top-level remains:

```
app/assets/post.rb
app/controllers/post.rb
app/helpers/post.rb
app/mailers/post.rb
app/models/post.rb
```

A matching file is found in `app/models/post.rb`. The lookup stops there and the
file is loaded. If the file actually defines `Post` all is fine, otherwise
`LoadError` is raised.

### Qualified References

When a qualified constant is missing Rails does not look for it in the parent
namespaces. But there is a caveat: when a constant is missing, Rails is
unable to tell if the trigger was a relative reference or a qualified one.

For example, consider

```ruby
module Admin
  User
end
```

and

```ruby
Admin::User
```

If `User` is missing, in either case all Rails knows is that a constant called
"User" was missing in a module called "Admin".

If there is a top-level `User` Ruby would resolve it in the former example, but
wouldn't in the latter. In general, Rails does not emulate the Ruby constant
resolution algorithms, but in this case it tries using the following heuristic:

> If none of the parent namespaces of the class or module has the missing
> constant then Rails assumes the reference is relative. Otherwise qualified.

For example, if this code triggers autoloading

```ruby
Admin::User
```

and the `User` constant is already present in `Object`, it is not possible that
the situation is

```ruby
module Admin
  User
end
```

because otherwise Ruby would have resolved `User` and no autoloading would have
been triggered in the first place. Thus, Rails assumes a qualified reference and
considers the file `admin/user.rb` and directory `admin/user` to be the only
valid options.

In practice, this works quite well as long as the nesting matches all parent
namespaces respectively and the constants that make the rule apply are known at
that time.

However, autoloading happens on demand. If by chance the top-level `User` was
not yet loaded, then Rails assumes a relative reference by contract.

Naming conflicts of this kind are rare in practice, but if one occurs,
`require_dependency` provides a solution by ensuring that the constant needed
to trigger the heuristic is defined in the conflicting place.

### Automatic Modules

When a module acts as a namespace, Rails does not require the application to
define a file for it, a directory matching the namespace is enough.

Suppose an application has a back office whose controllers are stored in
`app/controllers/admin`. If the `Admin` module is not yet loaded when
`Admin::UsersController` is hit, Rails needs first to autoload the constant
`Admin`.

If `autoload_paths` has a file called `admin.rb` Rails is going to load that
one, but if there's no such file and a directory called `admin` is found, Rails
creates an empty module and assigns it to the `Admin` constant on the fly.

### Generic Procedure

Relative references are reported to be missing in the cref where they were hit,
and qualified references are reported to be missing in their parent (see
[Resolution Algorithm for Relative
Constants](#resolution-algorithm-for-relative-constants) at the beginning of
this guide for the definition of *cref*, and [Resolution Algorithm for Qualified
Constants](#resolution-algorithm-for-qualified-constants) for the definition of
*parent*).

The procedure to autoload constant `C` in an arbitrary situation is as follows:

```
if the class or module in which C is missing is Object
  let ns = ''
else
  let M = the class or module in which C is missing

  if M is anonymous
    let ns = ''
  else
    let ns = M.name
  end
end

loop do
  # Look for a regular file.
  for dir in autoload_paths
    if the file "#{dir}/#{ns.underscore}/c.rb" exists
      load/require "#{dir}/#{ns.underscore}/c.rb"

      if C is now defined
        return
      else
        raise LoadError
      end
    end
  end

  # Look for an automatic module.
  for dir in autoload_paths
    if the directory "#{dir}/#{ns.underscore}/c" exists
      if ns is an empty string
        let C = Module.new in Object and return
      else
        let C = Module.new in ns.constantize and return
      end
    end
  end

  if ns is empty
    # We reached the top-level without finding the constant.
    raise NameError
  else
    if C exists in any of the parent namespaces
      # Qualified constants heuristic.
      raise NameError
    else
      # Try again in the parent namespace.
      let ns = the parent namespace of ns and retry
    end
  end
end
```


require_dependency
------------------

Constant autoloading is triggered on demand and therefore code that uses a
certain constant may have it already defined or may trigger an autoload. That
depends on the execution path and it may vary between runs.

There are times, however, in which you want to make sure a certain constant is
known when the execution reaches some code. `require_dependency` provides a way
to load a file using the current [loading mechanism](#loading-mechanism), and
keeping track of constants defined in that file as if they were autoloaded to
have them reloaded as needed.

`require_dependency` is rarely needed, but see a couple of use cases in
[Autoloading and STI](#autoloading-and-sti) and [When Constants aren't
Triggered](#when-constants-aren-t-missed).

WARNING. Unlike autoloading, `require_dependency` does not expect the file to
define any particular constant. Exploiting this behavior would be a bad practice
though, file and constant paths should match.


Constant Reloading
------------------

When `config.cache_classes` is false Rails is able to reload autoloaded
constants.

For example, if you're in a console session and edit some file behind the
scenes, the code can be reloaded with the `reload!` command:

```irb
irb> reload!
```

When the application runs, code is reloaded when something relevant to this
logic changes. In order to do that, Rails monitors a number of things:

* `config/routes.rb`.

* Locales.

* Ruby files under `autoload_paths`.

* `db/schema.rb` and `db/structure.sql`.

If anything in there changes, there is a middleware that detects it and reloads
the code.

Autoloading keeps track of autoloaded constants. Reloading is implemented by
removing them all from their respective classes and modules using
`Module#remove_const`. That way, when the code goes on, those constants are
going to be unknown again, and files reloaded on demand.

INFO. This is an all-or-nothing operation, Rails does not attempt to reload only
what changed since dependencies between classes makes that really tricky.
Instead, everything is wiped.

Common Gotchas
--------------

### Nesting and Qualified Constants

Let's consider

```ruby
module Admin
  class UsersController < ApplicationController
    def index
      @users = User.all
    end
  end
end
```

and

```ruby
class Admin::UsersController < ApplicationController
  def index
    @users = User.all
  end
end
```

To resolve `User` Ruby checks `Admin` in the former case, but it does not in
the latter because it does not belong to the nesting (see [Nesting](#nesting)
and [Resolution Algorithms](#resolution-algorithms)).

Unfortunately Rails autoloading does not know the nesting in the spot where the
constant was missing and so it is not able to act as Ruby would. In particular,
`Admin::User` will get autoloaded in either case.

Albeit qualified constants with `class` and `module` keywords may technically
work with autoloading in some cases, it is preferable to use relative constants
instead:

```ruby
module Admin
  class UsersController < ApplicationController
    def index
      @users = User.all
    end
  end
end
```

### Defining vs Reopening Namespaces

Let's consider:

```ruby
# app/models/blog.rb
module Blog
  def self.table_name_prefix
    "blog_"
  end
end
```

```ruby
# app/models/blog/post.rb
module Blog
  class Post < ApplicationRecord
  end
end
```

The table name for `Blog::Post` should be `blog_posts` due to the existence of
the method `Blog.table_name_prefix`. However, if `app/models/blog/post.rb` is
executed before `app/models/blog.rb` is, Active Record is not aware of the
existence of such method, and assumes the table is `posts`.

To resolve a situation like this, it helps thinking clearly about which file
_defines_ the `Blog` module (`app/models/blog.rb`), and which one _reopens_ it
(`app/models/blog/post.rb`). Then, you ensure that the definition is executed
first using `require_dependency`:

```ruby
# app/models/blog/post.rb

require_dependency "blog"

module Blog
  class Post < ApplicationRecord
  end
end
```

### Autoloading and STI

Single Table Inheritance (STI) is a feature of Active Record that enables
storing a hierarchy of models in one single table. The API of such models is
aware of the hierarchy and encapsulates some common needs. For example, given
these classes:

```ruby
# app/models/polygon.rb
class Polygon < ApplicationRecord
end
```

```ruby
# app/models/triangle.rb
class Triangle < Polygon
end
```

```ruby
# app/models/rectangle.rb
class Rectangle < Polygon
end
```

`Triangle.create` creates a row that represents a triangle, and
`Rectangle.create` creates a row that represents a rectangle. If `id` is the
ID of an existing record, `Polygon.find(id)` returns an object of the correct
type.

Methods that operate on collections are also aware of the hierarchy. For
example, `Polygon.all` returns all the records of the table, because all
rectangles and triangles are polygons. Active Record takes care of returning
instances of their corresponding class in the result set.

Types are autoloaded as needed. For example, if `Polygon.first` is a rectangle
and `Rectangle` has not yet been loaded, Active Record autoloads it and the
record is correctly instantiated.

All good, but if instead of performing queries based on the root class we need
to work on some subclass, things get interesting.

While working with `Polygon` you do not need to be aware of all its descendants,
because anything in the table is by definition a polygon, but when working with
subclasses Active Record needs to be able to enumerate the types it is looking
for. Let's see an example.

`Rectangle.all` only loads rectangles by adding a type constraint to the query:

```sql
SELECT "polygons".* FROM "polygons"
WHERE "polygons"."type" IN ("Rectangle")
```

Let's introduce now a subclass of `Rectangle`:

```ruby
# app/models/square.rb
class Square < Rectangle
end
```

`Rectangle.all` should now return rectangles **and** squares:

```sql
SELECT "polygons".* FROM "polygons"
WHERE "polygons"."type" IN ("Rectangle", "Square")
```

But there's a caveat here: How does Active Record know that the class `Square`
exists at all?

Even if the file `app/models/square.rb` exists and defines the `Square` class,
if no code yet used that class, `Rectangle.all` issues the query

```sql
SELECT "polygons".* FROM "polygons"
WHERE "polygons"."type" IN ("Rectangle")
```

That is not a bug, the query includes all *known* descendants of `Rectangle`.

A way to ensure this works correctly regardless of the order of execution is to
manually load the direct subclasses at the bottom of the file that defines each
intermediate class:

```ruby
# app/models/rectangle.rb
class Rectangle < Polygon
end
require_dependency 'square'
```

This needs to happen for every intermediate (non-root and non-leaf) class. The
root class does not scope the query by type, and therefore does not necessarily
have to know all its descendants.

### Autoloading and `require`

Files defining constants to be autoloaded should never be `require`d:

```ruby
require "user" # DO NOT DO THIS

class UsersController < ApplicationController
  # ...
end
```

There are two possible gotchas here in development mode:

1. If `User` is autoloaded before reaching the `require`, `app/models/user.rb`
runs again because `load` does not update `$LOADED_FEATURES`.

2. If the `require` runs first Rails does not mark `User` as an autoloaded
constant and changes to `app/models/user.rb` aren't reloaded.

Just follow the flow and use constant autoloading always, never mix
autoloading and `require`. As a last resort, if some file absolutely needs to
load a certain file use `require_dependency` to play nice with constant
autoloading. This option is rarely needed in practice, though.

Of course, using `require` in autoloaded files to load ordinary 3rd party
libraries is fine, and Rails is able to distinguish their constants, they are
not marked as autoloaded.

### Autoloading and Initializers

Consider this assignment in `config/initializers/set_auth_service.rb`:

```ruby
AUTH_SERVICE = if Rails.env.production?
  RealAuthService
else
  MockedAuthService
end
```

The purpose of this setup would be that the application uses the class that
corresponds to the environment via `AUTH_SERVICE`. In development mode
`MockedAuthService` gets autoloaded when the initializer runs. Let's suppose
we do some requests, change its implementation, and hit the application again.
To our surprise the changes are not reflected. Why?

As [we saw earlier](#constant-reloading), Rails removes autoloaded constants,
but `AUTH_SERVICE` stores the original class object. Stale, non-reachable
using the original constant, but perfectly functional.

The following code summarizes the situation:

```ruby
class C
  def quack
    'quack!'
  end
end

X = C
Object.instance_eval { remove_const(:C) }
X.new.quack # => quack!
X.name      # => C
C           # => uninitialized constant C (NameError)
```

Because of that, it is not a good idea to autoload constants on application
initialization.

In the case above we could implement a dynamic access point:

```ruby
# app/models/auth_service.rb
class AuthService
  if Rails.env.production?
    def self.instance
      RealAuthService
    end
  else
    def self.instance
      MockedAuthService
    end
  end
end
```

and have the application use `AuthService.instance` instead. `AuthService`
would be loaded on demand and be autoload-friendly.

### `require_dependency` and Initializers

As we saw before, `require_dependency` loads files in an autoloading-friendly
way. Normally, though, such a call does not make sense in an initializer.

One could think about doing some [`require_dependency`](#require-dependency)
calls in an initializer to make sure certain constants are loaded upfront, for
example as an attempt to address the [gotcha with STIs](#autoloading-and-sti).

Problem is, in development mode [autoloaded constants are wiped](#constant-reloading)
if there is any relevant change in the file system. If that happens then
we are in the very same situation the initializer wanted to avoid!

Calls to `require_dependency` have to be strategically written in autoloaded
spots.

### When Constants aren't Missed

#### Relative References

Let's consider a flight simulator. The application has a default flight model

```ruby
# app/models/flight_model.rb
class FlightModel
end
```

that can be overridden by each airplane, for instance

```ruby
# app/models/bell_x1/flight_model.rb
module BellX1
  class FlightModel < FlightModel
  end
end
```

```ruby
# app/models/bell_x1/aircraft.rb
module BellX1
  class Aircraft
    def initialize
      @flight_model = FlightModel.new
    end
  end
end
```

The initializer wants to create a `BellX1::FlightModel` and nesting has
`BellX1`, that looks good. But if the default flight model is loaded and the
one for the Bell-X1 is not, the interpreter is able to resolve the top-level
`FlightModel` and autoloading is thus not triggered for `BellX1::FlightModel`.

That code depends on the execution path.

These kind of ambiguities can often be resolved using qualified constants:

```ruby
module BellX1
  class Plane
    def flight_model
      @flight_model ||= BellX1::FlightModel.new
    end
  end
end
```

Also, `require_dependency` is a solution:

```ruby
require_dependency 'bell_x1/flight_model'

module BellX1
  class Plane
    def flight_model
      @flight_model ||= FlightModel.new
    end
  end
end
```

#### Qualified References

WARNING. This gotcha is only possible in Ruby < 2.5.

Given

```ruby
# app/models/hotel.rb
class Hotel
end
```

```ruby
# app/models/image.rb
class Image
end
```

```ruby
# app/models/hotel/image.rb
class Hotel
  class Image < Image
  end
end
```

the expression `Hotel::Image` is ambiguous because it depends on the execution
path.

As [we saw before](#resolution-algorithm-for-qualified-constants), Ruby looks
up the constant in `Hotel` and its ancestors. If `app/models/image.rb` has
been loaded but `app/models/hotel/image.rb` hasn't, Ruby does not find `Image`
in `Hotel`, but it does in `Object`:

```bash
$ bin/rails runner 'Image; p Hotel::Image' 2>/dev/null
Image # NOT Hotel::Image!
```

The code evaluating `Hotel::Image` needs to make sure
`app/models/hotel/image.rb` has been loaded, possibly with
`require_dependency`.

In these cases the interpreter issues a warning though:

```
warning: toplevel constant Image referenced by Hotel::Image
```

This surprising constant resolution can be observed with any qualifying class:

```irb
irb(main):001:0> String::Array
(irb):1: warning: toplevel constant Array referenced by String::Array
=> Array
```

WARNING. To find this gotcha the qualifying namespace has to be a class,
`Object` is not an ancestor of modules.

### Autoloading within Singleton Classes

Let's suppose we have these class definitions:

```ruby
# app/models/hotel/services.rb
module Hotel
  class Services
  end
end
```

```ruby
# app/models/hotel/geo_location.rb
module Hotel
  class GeoLocation
    class << self
      Services
    end
  end
end
```

If `Hotel::Services` is known by the time `app/models/hotel/geo_location.rb`
is being loaded, `Services` is resolved by Ruby because `Hotel` belongs to the
nesting when the singleton class of `Hotel::GeoLocation` is opened.

But if `Hotel::Services` is not known, Rails is not able to autoload it, the
application raises `NameError`.

The reason is that autoloading is triggered for the singleton class, which is
anonymous, and as [we saw before](#generic-procedure), Rails only checks the
top-level namespace in that edge case.

An easy solution to this caveat is to qualify the constant:

```ruby
module Hotel
  class GeoLocation
    class << self
      Hotel::Services
    end
  end
end
```

### Autoloading in `BasicObject`

Direct descendants of `BasicObject` do not have `Object` among their ancestors
and cannot resolve top-level constants:

```ruby
class C < BasicObject
  String # NameError: uninitialized constant C::String
end
```

When autoloading is involved that plot has a twist. Let's consider:

```ruby
class C < BasicObject
  def user
    User # WRONG
  end
end
```

Since Rails checks the top-level namespace `User` gets autoloaded just fine the
first time the `user` method is invoked. You only get the exception if the
`User` constant is known at that point, in particular in a *second* call to
`user`:

```ruby
c = C.new
c.user # surprisingly fine, User
c.user # NameError: uninitialized constant C::User
```

because it detects that a parent namespace already has the constant (see [Qualified
References](#autoloading-algorithms-qualified-references)).

As with pure Ruby, within the body of a direct descendant of `BasicObject` use
always absolute constant paths:

```ruby
class C < BasicObject
  ::String # RIGHT

  def user
    ::User # RIGHT
  end
end
```

### Autoloading in the Test Environment

When configuring the `test` environment for autoloading you might consider multiple factors.

For example it might be worth running your tests with an identical setup to production (`config.eager_load = true`, `config.cache_classes = true`) in order to catch any problems before they hit production (this is compensation for the lack of dev-prod parity). However this will slow down the boot time for individual tests on a dev machine (and is not immediately compatible with spring see below). So one possibility is to do this on a
[CI](https://en.wikipedia.org/wiki/Continuous_integration) machine only (which should run without spring).

On a development machine you can then have your tests running with whatever is fastest (ideally `config.eager_load = false`).

With the [Spring](https://github.com/rails/spring) pre-loader (included with new Rails apps), you ideally keep `config.eager_load = false` as per development. Sometimes you may end up with a hybrid configuration (`config.eager_load = true`, `config.cache_classes = true` AND `config.enable_dependency_loading = true`), see [spring issue](https://github.com/rails/spring/issues/519#issuecomment-348324369). However it might be simpler to keep the same configuration as development, and work out whatever it is that is causing autoloading to fail (perhaps by the results of your CI test results).

Occasionally you may need to explicitly eager_load by using `Rails
.application.eager_load!` in the setup of your tests -- this might occur if your [tests involve multithreading](https://stackoverflow.com/questions/25796409/in-rails-how-can-i-eager-load-all-code-before-a-specific-rspec-test).

## Troubleshooting

### Tracing Autoloads

Active Support is able to report constants as they are autoloaded. To enable these traces in a Rails application, put the following two lines in some initializer:

```ruby
ActiveSupport::Dependencies.logger = Rails.logger
ActiveSupport::Dependencies.verbose = true
```

### Where is a Given Autoload Triggered?

If constant `Foo` is being autoloaded, and you'd like to know where is that autoload coming from, just throw

```ruby
puts caller
```

at the top of `foo.rb` and inspect the printed stack trace.

### Which Constants Have Been Autoloaded?

At any given time,

```ruby
ActiveSupport::Dependencies.autoloaded_constants
```

has the collection of constants that have been autoloaded so far.
