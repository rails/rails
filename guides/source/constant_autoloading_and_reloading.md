Constant Autoloading and Reloading
==================================

This guide documents how constant autoloading and reloading works.

After reading this guide, you will know:

* Key aspects of Ruby constants

* What is `autoload_paths`

* How constant autoloading works

* What is `require_dependency`

* How constant reloading works

* That autoloading is not based on `Module#autoload`

* Solutions to common autoloading gotchas

--------------------------------------------------------------------------------


Introduction
------------

Ruby on Rails allows applications to be written as if all their code was
preloaded.

For example, in a normal Ruby program a class like the following controller
would need to load its dependencies:

```ruby
require 'application_controller'
require 'post'

class PostsController < ApplicationController
  def index
    @posts = Post.all
  end
end
```

Our Rubyist instinct quickly sees some redundancy in there: If classes were
defined in files matching their name, couldn't their loading maybe be automated
somehow? We could save scanning the file for dependencies, which is brittle.

Moreover, `Kernel#require` loads files once, but development is much more smooth
if code gets refreshed when it changes without restarting the server. It would
be nice to be able to use `Kernel#load` in development, and `Kernel#require` in
production.

Indeed, those features are provided by Ruby on Rails, where we just write this:

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.all
  end
end
```

This guide documents how that works.


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
account the by "parent namespace" the guide means exactly that specific string
derivation.

### Loading Mechanism

Rails autoloads files with `Kerne#load` when `config.cache_classes` is false,
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

```
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


Constants Refresher
-------------------

While constants are trivial in most programming languages, they are a rich
topic in Ruby.

It is beyond the scope of this guide to document Ruby constants, but we are
nevertheless going to highlight a couple of key topics. Truly grasping the
following two sections is instrumental to understanding constant autoloading and
reloading.

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
class Project < ActiveRecord::Base
end
```

performs a constant assignment equivalent to

```ruby
Project = Class.new(ActiveRecord::Base)
```

Similarly, module creation using the `module` keyword:

```ruby
module Admin
end
```

performs a constant assignment equivalent to

```ruby
Admin = Module.new
```

WARNING. The execution context of a block passed to `Class.new` or `Module.new`
is not entirely equivalent to the one of the body of the definitions using the
`class` and `module` keywords. But as far as this guide concerns, both idioms
perform the same constant assignment.

Thus, when one informally says "the `String` class", that really means: the
class object the interpreter creates and stores in a constant called "String" in
the class object stored in the `Object` constant. `String` is otherwise an
ordinary Ruby constant and everything related to constants applies to it,
resolution algorithms, etc.

Similarly, in the controller

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.all
  end
end
```

`Post` is not syntax for a class. Rather, `Post` is a regular Ruby constant. If
all is good, the constant evaluates to an object that responds to `all`.

That is why we talk about *constant autoloading*, Rails has the ability to load
constants on the fly.

### Constants are Stored in Modules

Constants belong to modules in a very literal sense. Classes and modules have
a constant table, think of it as a hash table.

Let's analyze an example to really understand what that means. While in a
casual setting some abuses of language are customary, the exposition is going
to be exact here for didactic purposes.

Let's consider the following module definition:

```ruby
module Colors
  RED = '0xff0000'
end
```

First, when the `module` keyword is processed the interpreter creates a new
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

Put special attention in the previous paragraphs to the distinction between
class and module objects, constant names, and value objects assiociated to them
in constant tables.


autoload_paths
--------------

As you probably know, when `require` gets a relative file name:

```ruby
require 'erb'
```

Ruby looks for the file in the directories listed in `$LOAD_PATH`. That is, Ruby
iterates over all its directories and for each one of them checks whether they
have a file called "erb.rb", or "erb.so", or "erb.o", or "erb.dll". If it finds
any of them, the interpreter loads it and ends the search. Otherwise, it tries
again in the next directory of the list. If the list gets exhausted, `LoadError`
is raised.

We are going to cover how constant autoloading works in more detail later, but
the idea is that when a constant like `Post` is hit and missing, if there's a
*post.rb* file for example in *app/models* Rails is going to find it, evaluate
it, and have `Post` defined as a side-effect.

Alright, Rails has a collection of directories similar to `$LOAD_PATH` in which
to lookup that *post.rb*. That collection is called `autoload_paths` and by
default it contains:

* All subdirectories of `app` in the application and engines. For example,
  `app/controllers`. They do not need to be the default ones, any custom
  directories like `app/workers` belong automatically to `autoload_paths`.

* Any existing second level directories called `app/*/concerns` in the
  application and engines.

* The directory `test/mailers/previews`.

Also, this collection is configurable via `config.autoload_paths`. For example,
`lib` was in the list years ago, but no longer is. An application can opt-in
throwing this to `config/application.rb`:

```ruby
config.autoload_paths += "#{Rails.root}/lib"
```

The value of `autoload_paths` can be inspected. In a just generated application
it is (edited):

```
$ bin/rails r 'puts ActiveSupport::Dependencies.autoload_paths'
.../app/assets
.../app/controllers
.../app/helpers
.../app/mailers
.../app/models
.../app/controllers/concerns
.../app/models/concerns
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
First checks if `app/assets/application_controller.rb` exists. If it does not,
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

INFO. 'Constant::Name'.underscore gives the relative path without extension of
the file name where `Constant::Name` is expected to be defined.

Let's see how does Rails autoload the `Post` constant in the `PostsController`
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
namespaces. But there's a caveat: Unfortunately, when a constant is missing
Rails is not able to say if the trigger was a relative or qualified reference.

For example, consider

```ruby
module Admin
  User # relative reference
end
```

and

```ruby
Admin::User # qualified reference
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

In practice this works quite well as long as the nesting matches all parent
namespaces respectively and the constants that make the rule apply are known at
that time.

But since autoloading happens on demand, if the top-level `User` by chance was
not yet loaded then Rails has no way to know whether `Admin::User` should load it
or raise `NameError`.

These kind of name conflicts are rare in practice, but in case there's one
`require_dependency` provides a solution by making sure the constant needed to
trigger the heuristic is defined in the conflicting place.

### Automatic Modules

When a module acts as a namespace, Rails does not require the application to
defines a file for it, a directory matching the namespace is enough.

Suppose an application has a backoffice whose controllers are stored in
`app/controllers/admin`. If the `Admin` module is not yet loaded when
`Admin::UsersController` is hit, Rails needs first to autoload the constant
`Admin`.

If `autoload_paths` has a file called `admin.rb` Rails is going to load that
one, but if there's no such file and a directory called `admin` is found, Rails
creates an empty module and assigns it to the `Admin` constant on the fly.

### Generic Procedure

The procedure to autoload constant `C` in an arbitrary situation is:

```
if the nesting is empty
  let ns = ''
else
  let M = nesting.first

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

`require_dependency` is rarely needed, but see a couple of use-cases in
[Autoloading and STI](#autoloading-and-sti) and [When Constants aren't
Triggered](#when-constants-aren-t-missed).

WARNING. Unlike autoloading, `require_dependency` does not expect the file to
define any particular constant. Exploiting this behavior would be a bad practice
though, file and constant paths should match.


Constant Reloading
------------------

When `config.cache_classes` is false Rails is able to reload autoloaded
constants.

For example, in you're in a console session and edit some file behind the
scenes, the code can be reloaded with the `reload!` command:

```
> reload!
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
going to be unkown again, and files reloaded on demand.

INFO. This is an all-or-nothing operation, Rails does not attempt to reload only
what changed since dependencies between classes makes that really tricky.
Instead, everything is wiped.


Module#autoload isn't Involved
------------------------------

`Module#autoload` provides a lazy way to load constants that is fully integrated
with the Ruby constant lookup algorithms, dynamic constant API, etc. It is quite
transparent.

Rails internals make extensive use of it to defer as much work as possible from
the boot process. But constant autoloading in Rails is **not** implemented with
`Module#autoload`.

One possible implementation based on `Module#autoload` would be to walk the
application tree and issue `autoload` calls that map existing file names to
their conventional contant name.

There are a number of reasons that prevent Rails from using that implementation.

For example, `Module#autoload` is only capable of loading files using `require`,
so reloading would not be possible. Not only that, it uses an internal `require`
which is not `Kernel#require`.

Then, it provides no way to remove declarations in case a file is deleted. If a
constant gets removed with `Module#remove_const` its `autoload` is not triggered
again. Also, it doesn't support qualified names, so files with namespaces should
be interpreted during the walk tree to install their own `autoload` calls, but
those files could have constant references not yet configured.

An implementation based on `Module#autoload` would be awesome but, as you see,
at least as of today it is not possible. Constant autoloading in Rails is
implemented with `Module#const_missing`, and that's why it has its own contract,
documented in this guide.


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

If Ruby resolves `User` in the former case it checks whether there's a `User`
constant in the `Admin` module. It does not in the latter case, because `Admin`
does not belong to the nesting.

Unfortunately Rails autoloading does not know the nesting in the spot where the
constant was missing and so it is not able to act as Ruby would. In particular,
if `Admin::User` is autoloadable, it will get autoloaded in either case.

Albeit qualified constants with `class` and `module` keywords may technically
work with autoloading in some cases, it is preferrable to use relative constants
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

### Autoloading and STI

STI (Single Table Inheritance) is a feature of Active Record that easies storing
records that belong to a hierarchy of classes in one single table. The API of
such models is aware of the hierarchy and encapsulates some common needs. For
example, given these classes:

```ruby
# app/models/polygon.rb
class Polygon < ActiveRecord::Base
end

# app/models/triangle.rb
class Triangle < Polygon
end

# app/models/rectangle.rb
class Rectangle < Polygon
end
```

`Triangle.create` creates a row that represents a triangle, and
`Rectangle.create` creates a row that represents a rectangle. If `id` is the ID
of an existing record, `Polygon.find(id)` returns an object of the correct type.

Methods that perform operations on collections are also aware of the hierarchy.
For example, `Polygon.all` returns all the records of the table, because all
rectangles and triangles are polygons. Active Record takes care of returning
instances of their corresponding class in the result set.

When Active Record does this, it autoloads constants as needed. For example, if
the class of `Polygon.first` is `Rectangle` and it has not yet been loaded,
Active Record autoloads it and the record is fetched and correctly instantiated,
transparently.

All good, but if instead of performing queries based on the root class we need
to work on some subclass, then things get interesting.

While working with `Polygon` you do not need to be aware of all its descendants,
because anything in the table is by definition a polygon, but when working with
subclasses Active Record needs to be able to enumerate the types it is looking
for. Let’s see an example.

`Rectangle.all` should return all the rectangles in the "polygons" table. In
particular, no triangle should be fetched. To accomplish this, Active Record
constraints the query to rows whose type column is “Rectangle”:

```sql
SELECT "polygons".* FROM "polygons"
WHERE "polygons"."type" IN ("Rectangle")
```

That works, but let’s introduce now a child of `Rectangle`:

```ruby
# app/models/square.rb
class Square < Rectangle
end
```

`Rectangle.all` should return rectangles **and** squares, the query should
become

```sql
SELECT "polygons".* FROM "polygons"
WHERE "polygons"."type" IN ("Rectangle", "Square")
```

But there’s a subtle caveat here: How does Active Record know that the class
`Square` exists at all?

Even if the file `app/models/square.rb` exists and defines the `Square` class,
if no code yet used that class, `Rectangle.all` issues the query

```sql
SELECT "polygons".* FROM "polygons"
WHERE "polygons"."type" IN ("Rectangle")
```

That is not a bug in Active Record, as we saw above the query does include all
*known* descendants of `Rectangle`.

A way to ensure this works correctly regardless of the order of execution is to
load the leaves of the tree by hand at the bottom of the file that defines the
root class:

```ruby
# app/models/polygon.rb
class Polygon < ActiveRecord::Base
end
require_dependency ‘square’
```

Only the leaves that are **at least grandchildren** have to be loaded that way.
Direct subclasses do not need to be preloaded, and if the hierarchy is deeper
intermediate superclasses will be autoloaded recursively from the bottom because
their constant will appear in the definitions.

### Autoloading and `require`

Files defining constants that should be autoloaded should never be loaded with
`require`:

```ruby
require 'user' # DO NOT DO THIS

class UsersController < ApplicationController
  ...
end
```

If some part of the application autoloads the `User` constant before, then the
application will interpret `app/models/user.rb` twice in development mode.

As we saw before, in development mode autoloading uses `Kernel#load` by default.
Since `load` does not store the name of the interpreted file in
`$LOADED_FEATURES` (`$"`) `require` executes, again, `app/models/user.rb`.

On the other hand, if `app/controllers/users_controllers.rb` happens to be
evaluated before `User` is autoloaded then dependencies won’t mark `User` as an
autoloaded constant, and therefore changes to `app/models/user.rb` won’t be
updated in development mode.

Just follow the flow and use constant autoloading always, never mix autoloading
and `require`. As a last resort, if some file absolutely needs to load a certain
file by hand use `require_dependency` to play nice with constant autoloading.
This option is rarely needed in practice, though.

Of course, using `require` in autoloaded files to load ordinary 3rd party
libraries is fine, and Rails is able to distinguish their constants, so they are
not marked as autoloaded.

### Autoloading and Initializers

Consider this assignment in `config/initializers/set_auth_service.rb`:

```ruby
AUTH_SERVICE = Rails.env.production? ? RealAuthService : MockedAuthService
```

The purpose of this setup would be that the application code uses always
`AUTH_SERVICE` and that constant holds the proper class for the runtime
environment. In development mode `MockedAuthService` gets autoloaded when the
initializer is run. Let’s suppose we do some requests, change the implementation
of `MockedAuthService`, and hit the application again. To our surprise the
changes are not reflected. Why?

As we saw earlier, Rails wipes autoloaded constants by removing them from their
containers using `remove_const`. But the object the constant holds may remain
stored somewhere else. Constant removal can’t do anything about that.

That is precisely the case in this example. `AUTH_SERVICE` stores the original
class object which is perfectly functional regardless of the fact that there is
no longer a constant in `Object` that matches its class name. The class object
is independent of the constants it may or may not be stored in.

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

In the case above we could for instance implement a dynamic access point that
returns something that depends on the environment:

```ruby
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

and have the application use `AuthService.instance` instead of `AUTH_SERVICE`.
The code in that `AuthService` would be loaded on demand and be
autoload-friendly.

### `require_dependency` and Initializers

As we saw before, `require_dependency` loads files in a autoloading-friendly
way. Normally, though, such a call does not make sense in an initializer.

`require_dependency` provides a way to ensure a certain constant is defined at
some point regardless of the execution path, and one could think about doing
some calls in an initialzer to make sure certain constants are loaded upfront,
for example as an attempt to address the gotcha with STIs.

Problem is, in development mode all autoloaded constants are wiped on a
subsequent request as soon as there is some relevant change in the file system.
When that happens the application is in the very same situation the initializer
wanted to avoid!

Calls to `require_dependency` have to be strategically written in autoloaded
spots.

### When Constants aren't Missed

Let’s imagine that a Rails application has an `Image` model, and a subclass
`Hotel::Image`:

```ruby
# app/models/image.rb
class Image
end

# app/models/hotel/image.rb
module Hotel
  class Image < Image
  end
end
```

No matter which file is interpreted first, `app/models/hotel/image.rb` is
well-defined.

Now consider a third file with this apparently harmless code:

```ruby
# app/models/hotel/poster.rb
module Hotel
  class Poster < Image
  end
end
```

The intention is to subclass `Hotel::Image`, but which is actually the
superclass of `Hotel::Poster`? Well, it depends on the order of execution of the
files:

1. If neither `app/models/image.rb` nor `app/models/hotel/image.rb` have been
loaded at that point, the superclass is `Hotel::Image` because Rails is told
`Hotel` is missing a constant called "Image" and loads
`app/models/hotel/image.rb`. Good.

2. If `app/models/hotel/image.rb` has been loaded at that point, the superclass
is `Hotel::Image` because Ruby is able to resolve the constant. Good.

3. Lastly, if only `app/models/image.rb` has been loaded so far, the superclass
is `Image`. Gotcha!

The last scenario (3) may be surprising. Why isn't `Hotel::Image` autoloaded?

Constant autoloading cannot happen at that point because Ruby is able to
resolve `Image` as a top-level constant, in consequence autoloading is not
triggered.

Most of the time, these kind of ambiguities can be resolved using qualified
constants. In this case we would write

```ruby
module Hotel
  class Poster < Hotel::Image
  end
end
```

That class definition now is robust. No matter which files have been
previously loaded, we know for certain that the superclass is unambiguously
set.

It is interesting to note here that fix works because `Hotel` is a module, and
`Hotel::Image` won’t look for `Image` in `Object` as it would if `Hotel` was a
class (because `Object` would be among its ancestors). If `Hotel` was class we
would resort to loading `Hotel::Image` with `require_dependency`. Furthermore,
with that solution the qualified name would no longer be necessary.

### Autoloading within Singleton Classes

Let’s suppose we have these class definitions:

```ruby
# app/models/hotel/services.rb
module Hotel
  class Services
  end
end

# app/models/hotel/geo_location.rb
module Hotel
  class GeoLocation
    class << self
      Services
    end
  end
end
```

1. If `Hotel::Services` is known by the time `Hotel::GeoLocation` is being loaded,
everything works because `Hotel` belongs to the nesting when the singleton class
of `Hotel::GeoLocation` is opened, and thus Ruby itself is able to resolve the
constant.

2. But if `Hotel::Services` is not known and we rely on autoloading for the
`Services` constant in `Hotel::GeoLocation`, Rails is not able to find
`Hotel::Services`. The application raises `NameError`.

The reason is that autoloading is triggered for the singleton class, which is
anonymous, and as we [saw before](#generic-procedure), Rails only checks the
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

because it detects a parent namespace already has the constant.

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
