h2. Active Record Basics

This guide is an introduction to Active Record. After reading this guide we hope that you'll learn:

* What Object Relational Mapping and Active Record are and how they are used in Rails
* How Active Record fits into the Model-View-Controller paradigm
* How to use Active Record models to manipulate data stored in a relational database
* Active Record schema naming conventions
* The concepts of database migrations, validations and callbacks

endprologue.

h3. What is Active Record?

Active Record is the M in "MVC":getting_started.html#the-mvc-architecture - the model - which is the layer of the system responsible for representing business data and logic. Active Record facilitates the creation and use of business objects whose data requires persistent storage to a database. It is an implementation of the Active Record pattern which itself is a description of an Object Relational Mapping system.

h4. The Active Record Pattern

Active Record was described by Martin Fowler in his book _Patterns of Enterprise Application Architecture_. In Active Record, objects carry both persistent data and behavior which operates on that data. Active Record takes the opinion that ensuring data access logic is part of the object will educate users of that object on how to write to and read from the database.

h4. Object Relational Mapping

Object-Relational Mapping, commonly referred to as its abbreviation ORM, is a technique that connects the rich objects of an application to tables in a relational database management system. Using ORM, the properties and relationships of the objects in an application can be easily stored and retrieved from a database without writing SQL statements directly and with less overall database access code.

h4. Active Record as an ORM Framework

Active Record gives us several mechanisms, the most important being the ability to:

* Represent models and their data
* Represent associations between these models
* Represent inheritance hierarchies through related models
* Validate models before they get persisted to the database
* Perform database operations in an object-oriented fashion.

h3. Convention over Configuration in Active Record

When writing applications using other programming languages or frameworks, it may be necessary to write a lot of configuration code. This is particularly true for ORM frameworks in general. However, if you follow the conventions adopted by Rails, you'll need to write very little configuration (in some case no configuration at all) when creating Active Record models. The idea is that if you configure your applications in the very same way most of the times then this should be the default way. In this cases, explicit configuration would be needed only in those cases where you can't follow the conventions for any reason.

h4. Naming Conventions

By default, Active Record uses some naming conventions to find out how the mapping between models and database tables should be created. Rails will pluralize your class names to find the respective database table. So, for a class +Book+, you should have a database table called *books*. The Rails pluralization mechanisms are very powerful, being capable to pluralize (and singularize) both regular and irregular words. When using class names composed of two or more words, the model class name should follow the Ruby conventions, using the CamelCase form, while the table name must contain the words separated by underscores. Examples:

* Database Table - Plural with underscores separating words (e.g., +book_clubs+)
* Model Class - Singular with the first letter of each word capitalized (e.g., +BookClub+)

|_.Model / Class |_.Table / Schema |
|+Post+          |+posts+|
|+LineItem+      |+line_items+|
|+Deer+          |+deer+|
|+Mouse+         |+mice+|
|+Person+        |+people+|


h4. Schema Conventions

Active Record uses naming conventions for the columns in database tables, depending on the purpose of these columns.

* *Foreign keys* - These fields should be named following the pattern +singularized_table_name_id+ (e.g., +item_id+, +order_id+). These are the fields that Active Record will look for when you create associations between your models.
* *Primary keys* - By default, Active Record will use an integer column named +id+ as the table's primary key. When using "Rails Migrations":migrations.html to create your tables, this column will be automatically created.

There are also some optional column names that will create additional features to Active Record instances:

* +created_at+ - Automatically gets set to the current date and time when the record is first created.
* +created_on+ - Automatically gets set to the current date when the record is first created.
* +updated_at+ - Automatically gets set to the current date and time whenever the record is updated.
* +updated_on+ - Automatically gets set to the current date whenever the record is updated.
* +lock_version+ - Adds "optimistic locking":http://api.rubyonrails.org/classes/ActiveRecord/Locking.html to a model.
* +type+ - Specifies that the model uses "Single Table Inheritance":http://api.rubyonrails.org/classes/ActiveRecord/Base.html
* +(table_name)_count+ - Used to cache the number of belonging objects on associations. For example, a +comments_count+ column in a +Post+ class that has many instances of +Comment+ will cache the number of existent comments for each post.

NOTE: While these column names are optional, they are in fact reserved by Active Record. Steer clear of reserved keywords unless you want the extra functionality. For example, +type+ is a reserved keyword used to designate a table using Single Table Inheritance (STI). If you are not using STI, try an analogous keyword like "context", that may still accurately describe the data you are modeling.

h3. Creating Active Record Models

It is very easy to create Active Record models. All you have to do is to subclass the +ActiveRecord::Base+ class and you're good to go:

<ruby>
class Product < ActiveRecord::Base
end
</ruby>

This will create a +Product+ model, mapped to a +products+ table at the database. By doing this you'll also have the ability to map the columns of each row in that table with the attributes of the instances of your model. Suppose that the +products+ table was created using an SQL sentence like:

<sql>
CREATE TABLE products (
   id int(11) NOT NULL auto_increment,
   name varchar(255),
   PRIMARY KEY  (id)
);
</sql>

Following the table schema above, you would be able to write code like the following:

<ruby>
p = Product.new
p.name = "Some Book"
puts p.name # "Some Book"
</ruby>

h3. Overriding the Naming Conventions

What if you need to follow a different naming convention or need to use your Rails application with a legacy database? No problem, you can easily override the default conventions.

You can use the +ActiveRecord::Base.table_name=+ method to specify the table name that should be used:

<ruby>
class Product < ActiveRecord::Base
  self.table_name = "PRODUCT"
end
</ruby>

If you do so, you will have to define manually the class name that is hosting the fixtures (class_name.yml) using the +set_fixture_class+ method in your test definition:

<ruby>
class FunnyJoke < ActiveSupport::TestCase
  set_fixture_class :funny_jokes => 'Joke'
  fixtures :funny_jokes
  ...
end
</ruby>

It's also possible to override the column that should be used as the table's primary key using the +ActiveRecord::Base.set_primary_key+ method:

<ruby>
class Product < ActiveRecord::Base
  set_primary_key "product_id"
end
</ruby>

h3. CRUD: Reading and Writing Data

CRUD is an acronym for the four verbs we use to operate on data: *C*reate, *R*ead, *U*pdate and *D*elete. Active Record automatically creates methods to allow an application to read and manipulate data stored within its tables.

h4. Create

Active Record objects can be created from a hash, a block or have their attributes manually set after creation. The +new+ method will return a new object while +create+ will return the object and save it to the database.

For example, given a model +User+ with attributes of +name+ and +occupation+, the +create+ method call will create and save a new record into the database:

<ruby>
  user = User.create(:name => "David", :occupation => "Code Artist")
</ruby>

Using the +new+ method, an object can be created without being saved:

<ruby>
  user = User.new
  user.name = "David"
  user.occupation = "Code Artist"
</ruby>

A call to +user.save+ will commit the record to the database.

Finally, if a block is provided, both +create+ and +new+ will yield the new object to that block for initialization:

<ruby>
  user = User.new do |u|
    u.name = "David"
    u.occupation = "Code Artist"
  end
</ruby>

h4. Read

Active Record provides a rich API for accessing data within a database. Below are a few examples of different data access methods provided by Active Record.

<ruby>
  # return array with all records
  users = User.all
</ruby>

<ruby>
  # return the first record
  user = User.first
</ruby>

<ruby>
  # return the first user named David
  david = User.find_by_name('David')
</ruby>

<ruby>
  # find all users named David who are Code Artists and sort by created_at in reverse chronological order
  users = User.where(:name => 'David', :occupation => 'Code Artist').order('created_at DESC')
</ruby>

You can learn more about querying an Active Record model in the "Active Record Query Interface":"active_record_querying.html" guide.

h4. Update

Once an Active Record object has been retrieved, its attributes can be modified and it can be saved to the database.

<ruby>
  user = User.find_by_name('David')
  user.name = 'Dave'
  user.save
</ruby>

h4. Delete

Likewise, once retrieved an Active Record object can be destroyed which removes it from the database.

<ruby>
  user = User.find_by_name('David')
  user.destroy
</ruby>

h3. Validations

Active Record allows you to validate the state of a model before it gets written into the database. There are several methods that you can use to check your models and validate that an attribute value is not empty, is unique and not already in the database, follows a specific format and many more. You can learn more about validations in the "Active Record Validations and Callbacks guide":active_record_validations_callbacks.html#validations-overview.

h3. Callbacks

Active Record callbacks allow you to attach code to certain events in the life-cycle of your models. This enables you to add behavior to your models by transparently executing code when those events occur, like when you create a new record, update it, destroy it and so on. You can learn more about callbacks in the "Active Record Validations and Callbacks guide":active_record_validations_callbacks.html#callbacks-overview.

h3. Migrations

Rails provides a domain-specific language for managing a database schema called migrations. Migrations are stored in files which are executed against any database that Active Record support using rake. Rails keeps track of which files have been committed to the database and provides rollback features. You can learn more about migrations in the "Active Record Migrations guide":migrations.html
