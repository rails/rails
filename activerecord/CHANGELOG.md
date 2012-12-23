## Rails 3.1.9

*  CVE-2012-5664 ensure that options are never taken from the first parameter

## Rails 3.1.8 (Aug 9, 2012)

*   No changes.

## Rails 3.1.7 (Jul 26, 2012)

*   No changes.

## Rails 3.1.6 (Jun 12, 2012)

*   protect against the nesting of hashes changing the
    table context in the next call to build_from_hash. This fix
    covers this case as well.

    CVE-2012-2695

## Rails 3.1.5 (May 31, 2012) ##

*   Fix type_to_sql with text and limit on mysql/mysql2. Fix GH #3931.

*   only log an error if there is a logger. fixes #5226

*   fix activerecord query_method regression with offset into Fixnum

*   predicate builder should not recurse for determining where columns.
    Thanks to Ben Murphy for reporting this! CVE-2012-2661

## Rails 3.1.4 (unreleased) ##

*   Fix a custom primary key regression *GH 3987*

    *Jon Leighton*

*   Perf fix (second try): don't load records for `has many :dependent =>
    :delete_all` *GH 3672*

    *Jon Leighton*

*   Fix accessing `proxy_association` method from an association extension
    where the calls are chained. *GH #3890*

    (E.g. `post.comments.where(bla).my_proxy_method`)

    *Jon Leighton*

*   Perf fix: MySQL primary key lookup was still slow for very large
    tables. *GH 3678*

    *Kenny J*

*   Perf fix: If a table has no primary key, don't repeatedly ask the database for it.

    *Julius de Bruijn*

## Rails 3.1.3 (unreleased) ##

*   Perf fix: If we're deleting all records in an association, don't add a IN(..) clause
    to the query. *GH 3672*

    *Jon Leighton*

*   Fix bug with referencing other mysql databases in set_table_name. *GH 3690*

*   Fix performance bug with mysql databases on a server with lots of other databses. *GH 3678*

    *Christos Zisopoulos and Kenny J*

## Rails 3.1.2 (unreleased) ##

*   Fix problem with prepared statements and PostgreSQL when multiple schemas are used.
    *GH #3232*

    *Juan M. Cuello*

*   Fix bug with PostgreSQLAdapter#indexes. When the search path has multiple schemas, spaces
    were not being stripped from the schema names after the first.

    *Sean Kirby*

*   Preserve SELECT columns on the COUNT for finder_sql when possible. *GH 3503*

    *Justin Mazzi*

*   Reset prepared statement cache when schema changes impact statement results. *GH 3335*

    *Aaron Patterson*

*   Postgres: Do not attempt to deallocate a statement if the connection is no longer active.

    *Ian Leitch*

*   Prevent QueryCache leaking database connections. *GH 3243*

    *Mark J. Titorenko*

*   Fix bug where building the conditions of a nested through association could potentially
    modify the conditions of the through and/or source association. If you have experienced
    bugs with conditions appearing in the wrong queries when using nested through associations,
    this probably solves your problems. *GH #3271*

    *Jon Leighton*

*   If a record is removed from a has_many :through, all of the join records relating to that
    record should also be removed from the through association's target.

    *Jon Leighton*

*   Fix adding multiple instances of the same record to a has_many :through. *GH #3425*

    *Jon Leighton*

*   Fix creating records in a through association with a polymorphic source type. *GH #3247*

    *Jon Leighton*

*   MySQL: use the information_schema than the describe command when we look for a primary key. *GH #3440*
    *Kenny J*

## Rails 3.1.1 (October 7, 2011) ##

*   Raise an exception if the primary key of a model in an association is needed
    but unknown. Fixes #3207.

    *Jon Leighton*

*   Add deprecation for the preload_associations method. Fixes #3022.

    *Jon Leighton*

*   Don't require a DB connection when loading a model that uses set_primary_key. GH #2807.

    *Jon Leighton*

*   Fix using select() with a habtm association, e.g. Person.friends.select(:name). GH #3030 and
    \#2923.

    *Hendy Tanata*

*   Fix belongs_to polymorphic with custom primary key on target. GH #3104.

    *Jon Leighton*

*   CollectionProxy#replace should change the DB records rather than just mutating the array.
    Fixes #3020.

    *Jon Leighton*

*   LRU cache in mysql and sqlite are now per-process caches.

    * lib/active_record/connection_adapters/mysql_adapter.rb: LRU cache
  	  keys are per process id.
    * lib/active_record/connection_adapters/sqlite_adapter.rb: ditto

    *Aaron Patterson*

*   Database adapters use a statement pool for limiting the number of open
    prepared statments on the database.  The limit defaults to 1000, but can
    be adjusted in your database config by changing 'statement_limit'.

*   Fix clash between using 'preload', 'joins' or 'eager_load' in a default scope and including the
    default scoped model in a nested through association. (GH #2834.) *Jon Leighton*

*   Ensure we are not comparing a string with a symbol in HasManyAssociation#inverse_updates_counter_cache?.
    Fixes GH #2755, where a counter cache could be decremented twice as far as it was supposed to be.

    *Jon Leighton*

*   Don't send any queries to the database when the foreign key of a belongs_to is nil. Fixes
    GH #2828. *Georg Friedrich*

*   Fixed find_in_batches method to not include order from default_scope. See GH #2832 *Arun Agrawal*

*   Don't compute table name for abstract classes. Fixes problem with setting the primary key
    in an abstract class. See GH #2791. *Akira Matsuda*

*   Psych errors with poor yaml formatting are proxied. Fixes GH #2645 and
    GH #2731

*   Use the LIMIT word with the methods #last and #first. Fixes GH #2783 *Damien Mathieu*

## Rails 3.1.0 (August 30, 2011) ##

*   Add a proxy_association method to association proxies, which can be called by association
    extensions to access information about the association. This replaces proxy_owner etc with
    proxy_association.owner.

    *Jon Leighton*

*   Active Record's dynamic finder will now show a deprecation warning if you passing in less number of arguments than what you call in method signature. This behavior will raise ArgumentError in the next version of Rails *Prem Sichanugrist*

*   Deprecated the AssociationCollection constant. CollectionProxy is now the appropriate constant
    to use, though be warned that this is not really a public API.

    This should solve upgrade problems with the will_paginate plugin (and perhaps others). Thanks
    Paul Battley for reporting.

    *Jon Leighton*

*   ActiveRecord::MacroReflection::AssociationReflection#build_record has a new method signature.

    Before: def build_association(*options)
    After:  def build_association(*options, &block)

    Users who are redefining this method to extend functionality should ensure that the block is
    passed through to ActiveRecord::Base#new.

    This change is necessary to fix https://github.com/rails/rails/issues/1842.

    A deprecation warning and workaround has been added to 3.1, but authors will need to update
    their code for it to work correctly in 3.2.

    *Jon Leighton*

*   AR#pluralize_table_names can be used to singularize/pluralize table name of an individual model:

        class User < ActiveRecord::Base
          self.pluralize_table_names = false
        end

    Previously this could only be set globally for all models through ActiveRecord::Base.pluralize_table_names. *Guillermo Iguaran*

*   Add block setting of attributes to singular associations:

        class User < ActiveRecord::Base
          has_one :account
        end

        user.build_account{ |a| a.credit_limit => 100.0 }

    The block is called after the instance has been initialized. *Andrew White*

*   Add ActiveRecord::Base.attribute_names to return a list of attribute names. This will return an empty array if the model is abstract or table does not exists. *Prem Sichanugrist*

*   CSV Fixtures are deprecated and support will be removed in Rails 3.2.0

*   AR#new, AR#create, AR#create!, AR#update_attributes and AR#update_attributes! all accept a second hash as option that allows you
    to specify which role to consider when assigning attributes. This is built on top of ActiveModel's
    new mass assignment capabilities:

        class Post < ActiveRecord::Base
          attr_accessible :title
          attr_accessible :title, :published_at, :as => :admin
        end

        Post.new(params[:post], :as => :admin)

    assign_attributes() with similar API was also added and attributes=(params, guard) was deprecated.

    Please note that this changes the method signatures for AR#new, AR#create, AR#create!, AR#update_attributes and AR#update_attributes!. If you have overwritten these methods you should update them accordingly.

    *Josh Kalderimis*

*   default_scope can take a block, lambda, or any other object which responds to `call` for lazy
    evaluation:

        default_scope { ... }
        default_scope lambda { ... }
        default_scope method(:foo)

    This feature was originally implemented by Tim Morgan, but was then removed in favour of
    defining a 'default_scope' class method, but has now been added back in by Jon Leighton.
    The relevant lighthouse ticket is #1812.

*   Default scopes are now evaluated at the latest possible moment, to avoid problems where
    scopes would be created which would implicitly contain the default scope, which would then
    be impossible to get rid of via Model.unscoped.

    Note that this means that if you are inspecting the internal structure of an
    ActiveRecord::Relation, it will *not* contain the default scope, though the resulting
    query will do. You can get a relation containing the default scope by calling
    ActiveRecord#with_default_scope, though this is not part of the public API.

    *Jon Leighton*

*   If you wish to merge default scopes in special ways, it is recommended to define your default
    scope as a class method and use the standard techniques for sharing code (inheritance, mixins,
    etc.):

        class Post < ActiveRecord::Base
          def self.default_scope
            where(:published => true).where(:hidden => false)
          end
        end

    *Jon Leighton*

*   PostgreSQL adapter only supports PostgreSQL version 8.2 and higher.

*   ConnectionManagement middleware is changed to clean up the connection pool
    after the rack body has been flushed.

*   Added an update_column method on ActiveRecord. This new method updates a given attribute on an object, skipping validations and callbacks.
    It is recommended to use #update_attribute unless you are sure you do not want to execute any callback, including the modification of
    the updated_at column. It should not be called on new records.
    Example:

        User.first.update_column(:name, "sebastian")         # => true

    *Sebastian Martinez*

*   Associations with a :through option can now use *any* association as the
    through or source association, including other associations which have a
    :through option and has_and_belongs_to_many associations

    *Jon Leighton*

*   The configuration for the current database connection is now accessible via
    ActiveRecord::Base.connection_config. *fxn*

*   limits and offsets are removed from COUNT queries unless both are supplied.
    For example:

        People.limit(1).count           # => 'SELECT COUNT(*) FROM people'
        People.offset(1).count          # => 'SELECT COUNT(*) FROM people'
        People.limit(1).offset(1).count # => 'SELECT COUNT(*) FROM people LIMIT 1 OFFSET 1'

    *lighthouse #6262*

*   ActiveRecord::Associations::AssociationProxy has been split. There is now an Association class
    (and subclasses) which are responsible for operating on associations, and then a separate,
    thin wrapper called CollectionProxy, which proxies collection associations.

    This prevents namespace pollution, separates concerns, and will allow further refactorings.

    Singular associations (has_one, belongs_to) no longer have a proxy at all. They simply return
    the associated record or nil. This means that you should not use undocumented methods such
    as bob.mother.create - use bob.create_mother instead.

    *Jon Leighton*

*   Make has_many :through associations work correctly when you build a record and then save it. This
    requires you to set the :inverse_of option on the source reflection on the join model, like so:

    class Post < ActiveRecord::Base
        has_many :taggings
        has_many :tags, :through => :taggings
    end

    class Tagging < ActiveRecord::Base
        belongs_to :post
        belongs_to :tag, :inverse_of => :tagging # :inverse_of must be set!
    end

    class Tag < ActiveRecord::Base
        has_many :taggings
        has_many :posts, :through => :taggings
    end

    post = Post.first
    tag = post.tags.build :name => "ruby"
    tag.save # will save a Taggable linking to the post

    *Jon Leighton*

*   Support the :dependent option on has_many :through associations. For historical and practical
    reasons, :delete_all is the default deletion strategy employed by association.delete(*records),
    despite the fact that the default strategy is :nullify for regular has_many. Also, this only
    works at all if the source reflection is a belongs_to. For other situations, you should directly
    modify the through association.

    *Jon Leighton*

*   Changed the behaviour of association.destroy for has_and_belongs_to_many and has_many :through.
    From now on, 'destroy' or 'delete' on an association will be taken to mean 'get rid of the link',
    not (necessarily) 'get rid of the associated records'.

    Previously, has_and_belongs_to_many.destroy(*records) would destroy the records themselves. It
    would not delete any records in the join table. Now, it deletes the records in the join table.

    Previously, has_many_through.destroy(*records) would destroy the records themselves, and the
    records in the join table. [Note: This has not always been the case; previous version of Rails
    only deleted the records themselves.] Now, it destroys only the records in the join table.

    Note that this change is backwards-incompatible to an extent, but there is unfortunately no
    way to 'deprecate' it before changing it. The change is being made in order to have
    consistency as to the meaning of 'destroy' or 'delete' across the different types of associations.

    If you wish to destroy the records themselves, you can do records.association.each(&:destroy)

    *Jon Leighton*

*   Add :bulk => true option to change_table to make all the schema changes defined in change_table block using a single ALTER statement. *Pratik Naik*

    Example:

    change_table(:users, :bulk => true) do |t|
        t.string :company_name
        t.change :birthdate, :datetime
    end

    This will now result in:

        ALTER TABLE `users` ADD COLUMN `company_name` varchar(255), CHANGE `updated_at` `updated_at` datetime DEFAULT NULL

*   Removed support for accessing attributes on a has_and_belongs_to_many join table. This has been
    documented as deprecated behaviour since April 2006. Please use has_many :through instead.
    *Jon Leighton*

*   Added a create_association! method for has_one and belongs_to associations. *Jon Leighton*

*   Migration files generated from model and constructive migration generators
    (for example, add_name_to_users) use the reversible migration's `change`
    method instead of the ordinary `up` and `down` methods. *Prem Sichanugrist*

*   Removed support for interpolating string SQL conditions on associations. Instead, you should
    use a proc, like so:

    Before:

        has_many :things, :conditions => 'foo = #{bar}'

    After:

        has_many :things, :conditions => proc { "foo = #{bar}" }

    Inside the proc, 'self' is the object which is the owner of the association, unless you are
    eager loading the association, in which case 'self' is the class which the association is within.

    You can have any "normal" conditions inside the proc, so the following will work too:

        has_many :things, :conditions => proc { ["foo = ?", bar] }

    Previously :insert_sql and :delete_sql on has_and_belongs_to_many association allowed you to call
    'record' to get the record being inserted or deleted. This is now passed as an argument to
    the proc.

*   Added ActiveRecord::Base#has_secure_password (via ActiveModel::SecurePassword) to encapsulate dead-simple password usage with BCrypt encryption and salting [DHH]. Example:

        # Schema: User(name:string, password_digest:string, password_salt:string)
        class User < ActiveRecord::Base
          has_secure_password
        end

        user = User.new(:name => "david", :password => "", :password_confirmation => "nomatch")
        user.save                                                      # => false, password required
        user.password = "mUc3m00RsqyRe"
        user.save                                                      # => false, confirmation doesn't match
        user.password_confirmation = "mUc3m00RsqyRe"
        user.save                                                      # => true
        user.authenticate("notright")                                  # => false
        user.authenticate("mUc3m00RsqyRe")                             # => user
        User.find_by_name("david").try(:authenticate, "notright")      # => nil
        User.find_by_name("david").try(:authenticate, "mUc3m00RsqyRe") # => user


*   When a model is generated add_index is added by default for belongs_to or references columns

    rails g model post user:belongs_to will generate the following:

        class CreatePosts < ActiveRecord::Migration
          def change
            create_table :posts do |t|
              t.belongs_to :user
              t.timestamps
            end
            add_index :posts, :user_id
          end
        end

    *Santiago Pastorino*

*   Setting the id of a belongs_to object will update the reference to the
    object. *#2989 state:resolved*

*   ActiveRecord::Base#dup and ActiveRecord::Base#clone semantics have changed
    to closer match normal Ruby dup and clone semantics.

*   Calling ActiveRecord::Base#clone will result in a shallow copy of the record,
    including copying the frozen state.  No callbacks will be called.

*   Calling ActiveRecord::Base#dup will duplicate the record, including calling
    after initialize hooks.  Frozen state will not be copied, and all associations
    will be cleared.  A duped record will return true for new_record?, have a nil
    id field, and is saveable.

*   Migrations can be defined as reversible, meaning that the migration system
    will figure out how to reverse your migration.  To use reversible migrations,
    just define the "change" method.  For example:

        class MyMigration < ActiveRecord::Migration
          def change
            create_table(:horses) do
              t.column :content, :text
              t.column :remind_at, :datetime
            end
          end
        end

    Some things cannot be automatically reversed for you.  If you know how to
    reverse those things, you should define 'up' and 'down' in your migration.  If
    you define something in `change` that cannot be reversed, an
    IrreversibleMigration exception will be raised when going down.

*   Migrations should use instance methods rather than class methods:
        class FooMigration < ActiveRecord::Migration
          def up
            ...
          end
        end

    *Aaron Patterson*

*   has_one maintains the association with separate after_create/after_update instead
    of a single after_save. *fxn*

*   The following code:

        Model.limit(10).scoping { Model.count }

    now generates the following SQL:

        SELECT COUNT(*) FROM models LIMIT 10

    This may not return what you want.  Instead, you may with to do something
    like this:

        Model.limit(10).scoping { Model.all.size }

    *Aaron Patterson*

Please check [3-0-stable](https://github.com/rails/rails/blob/3-0-stable/activerecord/CHANGELOG) for previous changes.
