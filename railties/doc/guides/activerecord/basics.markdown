Active Record Basics
====================



The ActiveRecord Pattern
------------------------

Active Record (the library) conforms to the active record design pattern.  The active record pattern is a design pattern often found in applications that use relational database.  The name comes from by Martin Fowler's book *Patterns of Enterprise Application Architecture*, in which he describes an active record object as:

> An object that wraps a row in a database table or view, encapsulates the database access, and adds domain logic on that data.

So, an object that follows the active record pattern encapsulates both data and behavior; in other words, they are responsible for saving and loading to the database and also for any domain logic that acts on the data.  The data structure of the Active Record should exactly match that of the database: one field in the class for each column in the table.

The Active Record class typically has methods that do the following:

* Construct an instances of an Active Record class from a SQL result
* Construct a new class instance for insertion into the table
* Get and set column values
* Wrap business logic where appropriate
* Update existing objects and update the related rows in the database

Mapping Your Database
---------------------

### Plural tables, singular classes ###

### Schema lives in the database ###

Creating Records
----------------

### Using save ###

### Using create ###

Retrieving Existing Rows
------------------------

### Using find ###

### Using find_by_* ###

Editing and Updating Rows
-------------------------

### Editing an instance

### Using update_all/update_attributes ###

Deleting Data
-------------

### Destroying a record ###

### Deleting a record ###