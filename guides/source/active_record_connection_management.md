**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

Active Record Connection Management
===================================

In general, Active Record will automagically manage database connections in an
effecient manner. See [Configuring a Database](/configuring.html#configuring-a-database)
and [Database pooling](configuring.html#database-pooling) for information about the
basics of optimally configuring your application to use available resources.

Sometimes, you will need to manage Active Record connections and/or connecton
pools yourself. These situations are:

* Configuring a multi-process web server
* Spawning processes

In previous version of rails, you needed to think about managing connections when
spawning threads, but this is no longer the case.

--------------------------------------------------------------------------------

Configuring a multi-process web server
--------------------------------------

Each process in a multi-process web server needs its own database connection pool.
If the server is also multi-threaded, the threads within each process will automatically
share that processes' connection pool.

Here is how to configure a server to set up its pools while booting your app:

### Before forking

Before the server forks, you need to disconnect the pool so that the forked processes
don't get confused. Here's how to do that in a puma config:

```ruby
before_fork do
  ActiveRecord::Base.connection_pool.disconnect!
end
```

### After forking

After a process forks and has no connections, it needs to establish connections.
Here's how to do that in a puma config:

```ruby
c.on_worker_boot do
  ActiveRecord::Base.establish_connection
end
```

Spawning processes
------------------

When spawning processes, you must do a small amount of manual database pool management.

Let's say you you have a script that you are going to run as a working using `rails runner`,
my_worker.rb. In this script, you are going to start two long-running processes.
Here's how you would go about doing that:

```ruby
ActiveRecord::Base.connection_pool.disconnect!
thing1_pid = Process.fork do
  ActiveRecord::Base.establish_connection

  Thing1.new.run
end

thing2_pid = Process.fork do
  ActiveRecord::Base.establish_connection

  Thing2.new.run
end

Process.wait thing1_pid
Process.wait thing2_pid
```

Note that each of the forked processes will have their own connection pool with
the number of connections configured in your app. So if database.yml specified a
connection pool of 5, then running `rails runner my_worker.rb` will use up to 10
connections.

Spawning threads
----------------

Rails will automatically allow threads to share connections from a connection pool.
As long as your app is configured to have at least as many connections as there are
threads running at the same time, you won't have to worry about managing connections.

You can experiment with this behavior in the console:

```ruby
500.times{ Thread.new{print User.count}.join }
# succeeds

500.times{ Thread.new{print User.count; sleep 1} }
# after a few successful threads, raises "could not obtain a connection from the pool"
```

Further Reading
---------------
* http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/AbstractAdapter.html
* http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/ConnectionPool.html
* https://github.com/puma/puma-heroku/blob/master/lib/puma/plugin/heroku.rb
* https://github.com/grosser/parallel#activerecord
* https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#on-worker-boot
* https://devcenter.heroku.com/articles/concurrency-and-database-connections#threaded-servers
* https://tenderlovemaking.com/2011/10/20/connection-management-in-activerecord.html

