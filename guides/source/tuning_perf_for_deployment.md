**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Tuning Performance for Deployment
=================================

This guide covers performance and concurrency configuration for deploying your production Ruby on Rails application.

After reading this guide, you will know:

* Whether to use Puma, the default application server
* How to configure important performance settings for Puma
* How to begin performance testing your application settings

This guide focuses on web servers, which are the primary performance-sensitive component of most web applications. Other components like background jobs and WebSockets can be tuned but won't be covered by this guide.

More information about how to configure your application can be found in the [Configuration Guide](configuring.html).

--------------------------------------------------------------------------------

Choosing an Application Server
------------------------------

Puma is Rails' default application server. It works well in most cases. In some cases, you may wish to change to another.

An application server uses a particular concurrency method. For example Unicorn uses processes, Puma and Passenger are hybrid process- and thread-based concurrency, Thin uses EventMachine, and Falcon uses Ruby Fibers.

A full discussion of Ruby's concurrency methods is beyond the scope of this document. If you want to use a method other than processes or threads, you will need to use a different application server. Some features are only available with a specific server, such as Pitchfork's reforking.

Most common application servers are used by removing the Puma gem from your Gemfile and including the gem for that server. Consult the appropriate application server documentation for details.

Ruby Concurrency
----------------

Ruby has many kinds of concurrency. Puma supports a hybrid process- and thread-based concurrency model.

This guide assumes you are running [CRuby](https://ruby-lang.org), the canonical implementation of Ruby. If you're using a Ruby implementation without a GVL nor forking support such as JRuby or TruffleRuby, most of this guide doesn't apply. If needed, check sources specific to your Ruby implementation.

### Process-Based Concurrency

Puma calls its multi-process concurrency "clustered mode". In this mode it forks new worker processes from a master process and each one separately processes requests. Each worker is a fully-capable Ruby process.

Each forked worker significantly increase memory usage since each worker contains all data from the parent process. But Ruby leverages [copy-on-write memory](https://en.wikipedia.org/wiki/Copy-on-write) to avoid duplicating most master-process data that doesn't change. But process-based workers often use a lot of memory, especially long-running workers.

Processes are resilient. Killing or crashing a single process doesn't affect other processes at all. Loading your application in the master process instead of the workers is called preloading. It can reduce memory usage by increasing the amount of memory that can be shared with the parent via copy-on-write.

### Thread-Based Concurrency

Multiple threads can run in the same process. This avoids multiple copies of shared data. Thread-based workers usually use much less memory than the same number of process-based workers.

[CRuby](https://www.ruby-lang.org/en/) has a [Global Interpreter Lock](https://en.wikipedia.org/wiki/Global_interpreter_lock), often called the GVL or GIL. The GVL prevents multiple threads from running Ruby code at the same time in a single process. Multiple threads can be waiting on network data, database operations or some other non-Ruby work, but only one can actively run Ruby code at a time. This means thread-based concurrency is more efficient for applications that use a lot of I/O such as database operations or network APIs. The more I/O your application uses, the more threads it would benefit from.

With the GVL, using a lot of threads has diminishing returns. A Rails app rarely benefits from more than 6. To have a large number of workers, some other concurrency method should be used.

Similarly, Ruby's garbage collector is "stop-the-world" so when it's triggered all threads have to stop. This also means diminishing returns for large numbers of threads.

Threads are less resilient than processes. Certain errors like segmentation faults can destroy the entire process and all threads inside. A single request allocating a lot of memory can stop all threads while the garbage collector runs.

### Hybrid Concurrency

Puma allows forking multiple processes, each of which uses multiple threads. This provides a compromise between process-based and thread-based concurrency. Using multiple threads per process helps memory usage. Multiple processes permit running more Ruby code at the same time since there is one GVL per process.

Hybrid concurrency limits the damage from a segmentation fault or other error that kills a process. A single process dying will kill that process's threads but not threads in other processes. Each process has its own independent garbage collector.

Choosing Default Settings
-------------------------

Rails' default settings aren't appropriate for all application sizes. You can improve performance for your I/O-heavy application that serves a lot of requests by changing settings.

This section contains common sense defaults based on the type and size of your application and the hosts on which it runs. You can improve performance more by testing your application specifically. See "Performance Testing" for details.

These are production recommendations. Your development application will have different needs from a production application, and should use a different configuration.

[Puma's deployment documentation](https://github.com/puma/puma/blob/master/docs/deployment.md) may also be useful.

### Threads Per Process

Rails uses 3 threads per process by default. A well-optimized I/O-heavy Rails application should specify 5 or 6 threads per process at maximum. Discourse, for example, benefits from about 5 threads per process. Discourse also executes many database queries per request and frequently uses Redis. More self-contained applications with fewer database and API queries benefit from around 3 threads per process.

The default Puma configuration mentions that "as a rule of thumb, increasing the number of threads will increase how much traffic a given process can handle (throughput), but due to CRuby's Global VM Lock (GVL) it has diminishing returns and will degrade the response time (latency) of the application."

To set the number of threads, you can change the call to the `threads` method in `config/puma.rb`. Or you can set the `RAILS_MAX_THREADS` environment variable, which will do the same. Make sure your `config/database.yml` file sets `pool` to be at least as high as the number of threads.

### Number of Processes

When using hybrid threads and processes, it's best to run 1 process per available processor core. On hosts with less memory you may need to choose a lower value. But fewer processes per core will normally result in not using all cores for your application. Automatic methods to determine the number of cores are unreliable, so you should specify the number of processes manually.

To set the number of worker processes, you can change the call to the `workers` method in `config/puma.rb`. Or you can set the `WEB_CONCURRENCY` environment variable, which will do the same.

### Preloading

Puma creates new workers from a master process. By loading your application code in the master process, you can avoid doing so after creating the worker. This permits sharing more memory across processes and prevents duplicate work.

In a few cases it may not make sense to preload your application. In that case it's possible to turn off application preloading.

Puma preloads your application by default by calling `preload_app!` in `config/puma.rb`. If you remove this call, your application will not be preloaded unless you specify a command line parameter to preload it.

### Memory Allocators and Configuration

CRuby normally uses your system's default memory allocator. You can switch to another allocator such as [jemalloc](https://github.com/jemalloc/jemalloc). You can also configure your allocator &mdash; e.g. Linux's glibc malloc allows setting MALLOC_ARENA_MAX to a low value like 2 to significantly reduce memory use.

This guide does not cover nonstandard allocators in significant detail. However, they can be a significant optimization relative to the system's default allocator. Long-running thread-based workers can be prone to memory fragmentation, which will reduce performance after many requests. A different allocator can help. The best tested by the Ruby community is jemalloc.

Performance Testing
-------------------

Settings from "Choosing Default Settings" are much better than using the initial Rails defaults. Your specific application may have unusual needs or benefit from different configuration options. Load testing takes effort, but can give you more benefit than default settings. You should implement reasonable defaults first.

The best way to choose your application's settings is to test the performance of your application with a simulated production workload. You should save your application's load testing code so you can re-run the tests with future versions of your application.

Performance testing is a deep subject. This guide gives only simple guidelines.

### Load Testers

You will need a load testing program to make requests of your application. This can be a dedicated load testing program of some kind, or you can write a small application to make HTTP requests and track how long they take. You should not normally check the time in your Rails logfile. That time is only how long Rails took to process the request. It does not include time taken by the application server.

Sending many simultaneous requests and timing them can be difficult. It is easy to introduce subtle measurement errors. Normally you should use a load testing program, not write your own. Many load testers are simple to use and many excellent load testers are free.

### What to Measure

Throughput is the number of requests per second that your application successfully processes. Any good load testing program will measure it. Throughput is normally a single number for each load test.

Latency is the delay from the time the request is sent until its response is successfully received. Each individual request will have its own latency.

[Percentile](https://en.wikipedia.org/wiki/Percentile_rank) latency gives the latency where a certain percentage of requests have better latency than that. For instance, P90 is the 90th-percentile latency. The P90 is the latency for a single load test where only 10% of requests look longer than that to process. The P50 is the latency such that half your requests were slower, also called the median latency.

"Tail latency" refers to high-percentile latencies. For instance, the P99 is the latency such that only 1% of your requests was worse. P99 is a tail latency. P50 is not a tail latency.

### What You Can Change

You can change the number of threads in your test to find the best tradeoff between throughput and latency for your application.

You can change the number of processes to trade off performance and expense in many cases. Larger hosts with more memory and CPU cores will need more processes for best usage. You can vary the size and type of hosts from a hosting provider.

You can also change other Puma configuration options such as wait_for_less_busy_worker, though you don't normally need to change them.

You can test changes to memory configuration, such as using a different allocator. These are often simple better/worse tests to validate that a particular configuration works better in your production environment.

Increasing the number of iterations will usually give a more exact answer, but require longer for testing.

YJIT is the default JIT in recent versions of CRuby. It reduces CPU usage but takes more memory. It's usually a good idea to enable it, but worth testing.

You should test on the same type of host that will run in production. Testing data for a development laptop will only tell you what settings are best for that development laptop.

### Warmup

Your application should process a number of requests after startup that are not included in your final measurements. These applications are called "warmup" requests, and are usually much slower than later "steady-state" requests.

Your load testing program will usually support warmup requests. You can also run it more than once and throw away the first set of times.

You have enough warmup requests when increasing the number does not significantly change your result. [The theory behind this can be complicated](https://arxiv.org/abs/1602.00602) but most common situations are straightforward: test several times with different amounts of warmup. See how many warmup iterations are needed before the results stay roughly the same.

Very long warmup can be useful for testing memory fragmentation and other issues that happen only after many requests.

### Which Requests

Your application probably accepts many different HTTP requests. You should begin by load testing with just a few of them. You can add more kinds of requests over time. If a particular kind of request is too slow in your production application, you can add it to your load testing code.

A synthetic workload cannot perfectly match your application's production traffic. It is still helpful for testing configurations.

### What to Look For

Your load testing program should allow you to check latencies, including percentile and tail latencies.

For different numbers of processes and threads, or different configurations in general, check the throughput and one or more latencies such as P50, P90, and P99. For very few threads, performance will usually be bad for all of these. Increasing the threads will improve latency up to a point, and then improve throughput but worsen latency after that.

Choose a tradeoff between latency and throughput based on your application's needs.
