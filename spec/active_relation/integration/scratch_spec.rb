require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe 'ActiveRelation', 'A proposed refactoring to ActiveRecord, introducing both a SQL
                            Builder and a Relational Algebra to mediate between
                            ActiveRecord and the database. The goal of the refactoring is
                            to remove code duplication concerning AR associations; remove
                            complexity surrounding eager loading; comprehensively solve
                            quoting issues; remove the with_scope merging logic; minimize
                            the need for with_scope in general; simplify the
                            implementation of plugins like HasFinder and ActsAsParanoid;
                            introduce an identity map; and allow for query optimization.
                            All this while remaining backwards-compatible with the
                            existing ActiveRecord interface.
                              The Relational Algebra makes these ambitious goals
                            possible. There\'s no need to be scared by the math, it\'s
                            actually quite simple. Relational Algebras have some nice
                            advantages over flexible SQL builders like Sequel and and
                            SqlAlchemy (a beautiful Python library). Principally, a
                            relation is writable as well as readable. This obviates the
                            :create with_scope, and perhaps also
                            #set_belongs_to_association_for.
                              With so much complexity removed from ActiveRecord, I
                            propose a mild reconsideration of the architecture of Base,
                            AssocationProxy, AssociationCollection, and so forth. These
                            should all be understood as \'Repositories\': a factory that
                            given a relation can manufacture objects, and given an object
                            can manipulate a relation. This may sound trivial, but I
                            think it has the potential to make the code smaller and
                            more consistent.' do
  before do
    class User < ActiveRecord::Base; has_many :photos end
    class Photo < ActiveRecord::Base; belongs_to :camera end
    class Camera < ActiveRecord::Base; end
  end
  
  before do
    # Rather than being associated with a table, an ActiveRecord is now associated with
    # a relation.
    @users = User.relation
    @photos = Photo.relation
    @cameras = Camera.relation
    # A first taste of a Relational Algebra: User.find(1)
    @user = @users.select(@users[:id].equals(1))    
    # == is overridden on attributes to return a predicate, not true or false
  end

  # In a Relational Algebra, the various ActiveRecord associations become a simple
  # mapping from one relation to another. The Reflection object parameterizes the
  # mapping.
  def user_has_many_photos(user_relation)
    primary_key = User.reflections[:photos].klass.primary_key.to_sym
    foreign_key = User.reflections[:photos].primary_key_name.to_sym
    
    user_relation.outer_join(@photos).on(user_relation[primary_key].equals(@photos[foreign_key]))
  end
  
  def photo_belongs_to_camera(photo_relation)
    primary_key = Photo.reflections[:camera].klass.primary_key.to_sym
    foreign_key = Photo.reflections[:camera].primary_key_name.to_sym

    photo_relation.outer_join(@cameras).on(photo_relation[foreign_key].equals(@cameras[primary_key]))
  end

  describe 'Relational Algebra', 'a relational algebra allows the implementation of
                                  associations like has_many to be specified once,
                                  regardless of eager-joins, has_many :through, and so
                                  forth' do    
    it 'generates the query for User.has_many :photos' do
      user_photos = user_has_many_photos(@user)
      # the 'project' operator limits the columns that come back from the query.
      # Note how all the operators are compositional: 'project' is applied to a query
      # that previously had been joined and selected.
      user_photos.project(*@photos.attributes).to_sql.should be_like("""
        SELECT `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`
        FROM `users`
          LEFT OUTER JOIN `photos`
            ON `users`.`id` = `photos`.`user_id`
        WHERE
          `users`.`id` = 1
      """)
      # Also note the correctly quoted columns and tables. In this instance the
      # MysqlAdapter from ActiveRecord is used to do the escaping.
    end
  
    it 'generates the query for User.has_many :cameras, :through => :photos' do
      # note, again, the compositionality of the operators:
      user_cameras = photo_belongs_to_camera(user_has_many_photos(@user))
      user_cameras.project(*@cameras.attributes).to_sql.should be_like("""
        SELECT `cameras`.`id`
        FROM `users`
          LEFT OUTER JOIN `photos`
            ON `users`.`id` = `photos`.`user_id`
          LEFT OUTER JOIN `cameras`
            ON `photos`.`camera_id` = `cameras`.`id`
        WHERE
          `users`.`id` = 1
      """)
    end
    
    it 'generates the query for an eager join for a collection using the same logic as
        for an association on an individual row' do
      users_cameras = photo_belongs_to_camera(user_has_many_photos(@users))
      users_cameras.to_sql.should be_like("""
        SELECT `users`.`name`, `users`.`id`, `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`, `cameras`.`id`
        FROM `users`
          LEFT OUTER JOIN `photos`
            ON `users`.`id` = `photos`.`user_id`
          LEFT OUTER JOIN `cameras`
            ON `photos`.`camera_id` = `cameras`.`id`
      """)
    end
    
    it 'is trivial to disambiguate columns' do
      users_cameras = photo_belongs_to_camera(user_has_many_photos(@users)).qualify
      users_cameras.to_sql.should be_like("""
        SELECT `users`.`name` AS 'users.name', `users`.`id` AS 'users.id', `photos`.`id` AS 'photos.id', `photos`.`user_id` AS 'photos.user_id', `photos`.`camera_id` AS 'photos.camera_id', `cameras`.`id` AS 'cameras.id'
        FROM `users`
          LEFT OUTER JOIN `photos`
            ON `users`.`id` = `photos`.`user_id`
          LEFT OUTER JOIN `cameras`
            ON `photos`.`camera_id` = `cameras`.`id`
      """)
    end
    
    it 'allows arbitrary sql to be passed through' do
      @users.outer_join(@photos).on("asdf").to_sql.should be_like("""
        SELECT `users`.`name`, `users`.`id`, `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`
        FROM `users`
          LEFT OUTER JOIN `photos`
            ON asdf
      """)
      @users.select("asdf").to_sql.should be_like("""
        SELECT `users`.`name`, `users`.`id`
        FROM `users`
        WHERE asdf
      """)
    end

    describe 'write operations' do
      it 'generates the query for user.destroy' do
        @user.delete.to_sql.should be_like("""
          DELETE
          FROM `users`
          WHERE `users`.`id` = 1
        """)
      end
      
     it 'generates an efficient query for two User.creates -- UnitOfWork is within reach!' do
        @users.insert(@users[:name] => "humpty").insert(@users[:name] => "dumpty").to_sql.should be_like("""
          INSERT
          INTO `users`
          (`users`.`name`) VALUES ('humpty'), ('dumpty')
        """)
      end
    end

    describe 'with_scope' do
      it 'obviates the need for with_scope merging logic since, e.g.,
            `with_scope :conditions => ...` is just a #select operation on the relation' do
      end
    
      it 'may eliminate the need for with_scope altogether since the associations no longer
          need it: the relation underlying the association fully encapsulates the scope' do
      end
    end
  end

  describe 'Repository', 'ActiveRecord::Base, HasManyAssociation, and so forth are
                          all repositories: given a relation, they manufacture objects' do
    before do
      class << ActiveRecord::Base; public :instantiate end
    end
  
    it 'manufactures objects' do
      User.instantiate(@users.first).attributes.should == {"name" => "hai", "id" => 1}
    end
    
    it 'frees ActiveRecords from being tied to tables' do
      pending # pending, but trivial to implement:
      
      class User < ActiveRecord::Base
        # acts_as_paranoid without alias_method_chain:
        set_relation @users.select(@users[:deleted_at] != nil)
      end
      
      class Person < ActiveRecord::Base
        set_relation @accounts.join(@profiles).on(@accounts[:id].equals(@profiles[:account_id]))
      end
      # I know this sounds crazy, but even writes are possible in the last example.
      # calling #save on a person can write to two tables!
    end
    
    describe 'the n+1 problem' do      
      describe 'the eager join algorithm is vastly simpler' do
        it 'loads three active records with only one query' do
          # using 'rr' mocking framework: the real #select_all is called, but we assert
          # that it only happens once:
          mock.proxy(ActiveRecord::Base.connection).select_all.with_any_args.once
          
          users_cameras = photo_belongs_to_camera(user_has_many_photos(@users)).qualify
          user = User.instantiate(users_cameras.first, [:photos => [:camera]])
          user.photos.first.camera.attributes.should == {"id" => 1}
        end

        before do
          class << ActiveRecord::Base
            # An identity map makes this algorithm efficient.
            def instantiate_with_cache(record)
              cache.get(record) { instantiate_without_cache(record) }
            end
            alias_method_chain :instantiate, :cache

            # for each row in the result set, which may contain data from n tables,
            #  - instantiate that slice of the data corresponding to the current class
            #  - recusively walk the dependency chain and repeat.
            def instantiate_with_joins(data, joins = [])
              record = unqualify(data)
              returning instantiate_without_joins(record) do |object|
                joins.each do |join|
                  case join
                  when Symbol
                    object.send(association = join).instantiate(data)
                  when Hash
                    join.each do |association, nested_associations|
                      object.send(association).instantiate(data, nested_associations)
                    end
                  end
                end
              end
            end
            alias_method_chain :instantiate, :joins
            
            private
            # Sometimes, attributes are qualified to remove ambiguity. Here, bring back
            # ambiguity by translating 'users.id' to 'id' so we can call #attributes=.
            # This code should work correctly if the attributes are qualified or not.
            def unqualify(qualified_attributes)
              qualified_attributes_for_this_class = qualified_attributes. \
                slice(*relation.attributes.collect(&:qualified_name))
              qualified_attributes_for_this_class.alias do |qualified_name|
                qualified_name.split('.')[1] || qualified_name # the latter means it must not really be qualified
              end
            end
          end
        end
        
        it "is possible to be smarter about eager loading. DataMapper is smart enough
            to notice when you do users.each { |u| u.photos } and make this two queries
            rather than n+1: the first invocation of #photos is lazy but it preloads
            photos for all subsequent users. This is substantially easier with the
            Algebra since we can do @user.join(@photos).on(...) and transform that to
            @users.join(@photos).on(...), relying on the IdentityMap to eliminate
            the n+1 problem." do
          pending
        end
      end
    end
  end
  
  describe 'The Architecture', 'I propose to produce a new gem, ActiveRelation, which encaplulates
                                the existing ActiveRecord Connection Adapter, the new SQL Builder,
                                and the Relational Algebra. ActiveRecord, then, should no longer
                                interact with the connection object directly.' do
  end
  
  describe 'Miscellaneous Ideas' do
    it 'may be easy to write a SQL parser that can take arbitrary SQL and produce a relation.
        This has the advantage of permitting e.g., pagination with custom finder_sql'
  end
end