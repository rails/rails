
**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Tuning Performance for Deployment
=================================

This guide covers performance and concurrency configuration for deploying your Ruby on Rails application to production.

After reading this guide, you will know:

* How Ruby's concurrency model affects application performance.
* How to configure Puma workers, threads, and database connection pools.
* How YJIT and memory allocators affect performance and memory usage.
* How to measure performance and tune your configuration for your application's workload.

This guide focuses on web application servers. For background job configuration, see
[Active Job Basics](active_job_basics.html). For WebSocket configuration and deployment, see
[Action Cable Overview](action_cable_overview.html). Database query optimization and caching
are outside this guide's scope; related guidance is available in
[Active Record Query Interface](active_record_querying.html) and
[Caching with Rails](caching_with_rails.html).

For general application configuration, see [Configuring Rails Applications](https://guides.rubyonrails.org/configuring.html). For more information about concurrency, see [Threading and Code Execution in Rails](https://guides.rubyonrails.org/threading_and_code_execution.html).

--------------------------------------------------------------------------------

NOTE: This guide covers standard Ruby, also known as CRuby or MRI. Run `ruby -v` to check your implementation. Some concurrency considerations differ for  `jruby` or `truffleruby`.

Choosing an Application Server
-----------------------------

An application server receives HTTP requests, runs your Rails application, and returns responses. Servers differ in how they handle concurrent requests.

Puma is Rails' default application server and is suitable for many applications. It uses a thread pool and can run multiple worker processes. Other servers use different concurrency models; for example, Falcon uses fibers. This guide focuses on tuning Puma.

Setting Performance Goals
-------------------------

Performance tuning involves balancing throughput, latency, and resource usage:

* **Throughput** is the number of requests successfully processed per second.
* **Latency** is the time from sending a request to receiving its response.
* **Resource usage** includes CPU, memory, and database connections.

Higher throughput can reduce the infrastructure needed to serve a workload. Lower latency makes the application more responsive. These goals can conflict: increasing concurrency may improve throughput while making individual requests wait longer for CPU time or other resources.

Define acceptable performance before comparing configurations. For example, a goal might be to sustain an expected peak of 100 requests per second for a representative workload, with P95 latency below 300 milliseconds and fewer than 0.1% failed requests, including timeouts. These values are illustrative; choose targets that reflect your application's users and requirements. Specify the workload, measurement period, and whether the target applies to the whole application or particular endpoints.

Start with your application's existing configuration and a workload representative of production:

1. Establish a baseline for throughput, latency, errors, and resource usage.
2. Investigate which resources constrain performance.
3. Change one setting at a time.
4. Repeat the same measurements and compare the results.
5. Keep changes that meet your performance goals within your resource limits.

Understanding Ruby's Concurrency Model
-------------------------------------

Puma handles requests using threads within a process. In cluster mode, it starts separate worker processes, each with its own thread pool and instance of the application.

Two workers with a maximum of three request threads each provide up to six request-processing slots. This is a limit on concurrent request handling, not a guarantee that six requests can execute Ruby code simultaneously.

### Request Queuing and Saturation

When all request threads are occupied, additional requests must wait for capacity or be rejected or time out, depending on the deployment. Waiting can occur at several points, including a reverse proxy, the operating system's connection backlog, or the application server. This queuing time contributes to the latency users experience even before Rails begins processing a request.

If requests keep arriving faster than the deployment can complete them, queues grow until a limit is reached. Near this point of saturation, successful throughput may stop increasing while tail latency and timeouts rise. A deployment can also reach unacceptable latency before its maximum throughput is reached.

Adding request threads can help if there is capacity available to do useful work. If the database is already saturated, however, allowing more requests to query it concurrently may increase contention and make each request slower. More workers or a larger connection pool can have the same effect. Tune concurrency against the capacity of the whole request path, including shared dependencies.

### Threads and the Global VM Lock

[CRuby](https://www.ruby-lang.org/en/) has a [Global Interpreter Lock](https://en.wikipedia.org/wiki/Global_interpreter_lock), often called the GVL or GIL. The GVL prevents multiple threads from executing Ruby code under the lock simultaneously within the same process.

Consider one request waiting for a database query and another performing a calculation in Ruby. When the database operation releases the GVL while waiting, another thread can execute the calculation. Both requests make progress concurrently. If both requests are executing Ruby calculations under the GVL, they must take turns.

Applications that spend substantial time waiting for I/O may benefit from additional threads. For workloads that spend most of their time executing Ruby code, additional threads can instead increase contention for the GVL. Threads also consume memory and may increase latency when requests compete for resources.

NOTE: Native extensions and some runtime operations can execute outside the GVL. A multithreaded CRuby process can therefore use more than one CPU core, even though ordinary Ruby execution under the GVL is serialized.

Garbage collection also affects latency. CRuby's garbage collector includes phases that pause Ruby execution within a process. During these pauses, request threads in that process cannot continue executing Ruby code. The duration and frequency of pauses depend on the workload and Ruby version.

### Worker Processes and Memory

Each worker has its own GVL, so separate workers can execute Ruby code in parallel when CPU capacity is available. Adding workers generally consumes more memory than adding threads.

On systems that support forking, workers can share memory pages through [copy-on-write](https://en.wikipedia.org/wiki/Copy-on-write). A shared page becomes private when a process modifies it. Loading the application before forking can increase sharing, but allocations, mutations, and garbage collection during normal operation affect how much memory remains shared.

Puma supports application preloading in cluster mode. Its defaults and lifecycle hooks depend on the Puma version and configuration. Review [Puma's cluster and preload documentation](https://puma.io/puma/file.README.html#label-Cluster+mode) before changing preloading, particularly if application initialization creates connections or background threads.

Grouping more workers on fewer hosts may reduce memory overhead per worker through copy-on-write sharing of preloaded application memory. The savings depend on how much memory remains shared under load. Compare the measured footprint with the capacity, availability, and deployment requirements of each arrangement.

Measure memory after warmup and under sustained load. Summing process resident memory can count shared pages more than once; use container or host memory measurements to assess the deployment's total footprint. Leave capacity for the Puma master process, other services, and temporary increases during restarts.

### Thread Safety

Each request has its own controller instance, but threads in a process share classes, class variables, global variables, and objects referenced by constants or caches. Rails' thread-safe autoloading does not make arbitrary application state thread-safe.

Avoid mutating shared objects during requests unless a thread-safe API or synchronization mechanism protects the operation. Store request-specific data in method-local variables, objects created for the request, or appropriately scoped attributes in `ActiveSupport::CurrentAttributes`.

When creating threads or managing custom thread pools, wrap application code in the Rails Executor so Rails can manage execution state and clean up resources. See [Threading and Code Execution in Rails](https://guides.rubyonrails.org/threading_and_code_execution.html) for details.

Configuring the Application
---------------------------

### Puma Workers and Threads

Puma's configuration resides in `config/puma.rb`. The `threads` directive sets the minimum and maximum request-thread pool sizes. The `workers` directive sets the number of worker processes; a value of `0` selects single mode, where the application runs in one process without cluster workers.

The following example uses two workers, each with three request threads:

```ruby
# config/puma.rb
threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", "3"))
threads threads_count, threads_count

workers ENV.fetch("WEB_CONCURRENCY", "2")

port ENV.fetch("PORT", "3000")
environment ENV.fetch("RAILS_ENV", "development")
```

Start this example in production with:

```bash
RAILS_ENV=production WEB_CONCURRENCY=2 RAILS_MAX_THREADS=3 bundle exec puma -C config/puma.rb
```

These counts illustrate the configuration; they are not recommendations for every application. Incorporate the relevant settings into your existing configuration, preserving any deployment-specific hooks and plugins.

One worker per CPU core allocated to the application can be a useful starting point if memory permits. Account for CPU quotas, other processes, and the application's workload. More workers than available cores may help when workers spend time waiting for I/O, but can also increase CPU contention and memory usage.

If memory limits prevent you from running enough workers to use the available CPU capacity, consider a hosting plan with more memory per CPU core. Conversely, adding CPU capacity alone may provide little benefit while memory remains the constraint. Compare host configurations using the same representative workload and include their cost in the decision.

Puma supports `WEB_CONCURRENCY=auto` in versions with automatic worker detection. It requires `concurrent-ruby` and uses its available processor count. Check the resulting worker count against the CPU capacity actually allocated by your hosting platform, especially on shared hosts or in containers. See [Puma's configuration implementation](https://github.com/puma/puma/blob/main/lib/puma/configuration.rb).

### Database Connection Pools

Active Record manages database connections through pools configured in `config/database.yml`. Each worker has its own pools. Applications using multiple databases, roles, or shards can have several pools per process.

For synchronous queries, a pool at least as large as the maximum number of Puma request threads is a common starting point:

```yaml
# Add this setting to the existing production database configuration.
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 3) %>
```

If five request threads need connections simultaneously but only three are available, some threads must wait. A larger pool can reduce this wait, but connections also consume database resources. Raising the limit does not address slow queries or a database that is already overloaded.

For a deployment with one pool per worker connecting to the same database, the configured web connection capacity is:

```text
Application instances × Workers per instance × Pool size
```

For example, two application instances with two workers each and a pool size of three can open up to twelve connections across those pools. Pools open connections as needed, so their limits are not necessarily their current usage. For Puma single mode, count one application process per instance.

Budget separately for background jobs, consoles, additional pools, and overlapping processes during deployments. Compare the combined capacity with the database's connection limit.

Asynchronous queries also need pool capacity. With Active Record's global async query executor, the documented minimum is the maximum foreground thread count plus `global_executor_concurrency` plus one. Three request threads and an executor concurrency of four therefore require a pool of at least eight, before accounting for other users of that pool. See [`config.active_record.global_executor_concurrency`](https://guides.rubyonrails.org/configuring.html#config-active-record-global-executor-concurrency).

PostgreSQL prepared statements can improve query performance but use server memory per connection. If this contributes to memory pressure, review `statement_limit` and prepared statement settings in [Configuring a PostgreSQL Database](https://guides.rubyonrails.org/configuring.html#configuring-a-postgresql-database).

### YJIT

[YJIT](https://github.com/ruby/ruby/blob/master/doc/yjit/yjit.md) is CRuby's [just-in-time compiler](https://en.wikipedia.org/wiki/Just-in-time_compilation). It compiles frequently executed Ruby code into machine code and can improve performance at the cost of additional memory. When your Ruby build supports YJIT and the deployment has memory to spare, start by evaluating the application with YJIT enabled. Compare throughput, latency, and memory usage with it disabled after warming up both configurations under the same workload.

Rails can enable YJIT through `config.yjit` on supported Ruby builds beginning with Ruby 3.3. The default depends on `config.load_defaults`: Rails 7.2 defaults enable it, while Rails 8.1 defaults enable it outside local environments. Upgrading Rails does not necessarily adopt newer configuration defaults. See [`config.yjit`](https://guides.rubyonrails.org/configuring.html#config-yjit).

Check its status in the running application:

```ruby
defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
```

If memory is constrained, compare disabling YJIT with reducing its memory budget. Available options vary by Ruby version; for example, Ruby 3.4 documents `--yjit-mem-size`. This budget is not a limit on the entire process's memory. Consult the [YJIT documentation for your Ruby version](https://docs.ruby-lang.org/en/3.4/yjit/yjit_md.html) before changing it.

### Memory Allocators

[Memory fragmentation](https://en.wikipedia.org/wiki/Fragmentation_(computing)) can cause a process to retain more resident memory than its live application objects require. With multithreaded Ruby workloads, allocator behavior can affect how many workers fit within a memory limit.

An alternative allocator such as [jemalloc](https://github.com/jemalloc/jemalloc) may reduce fragmentation. Rails' generated Dockerfile includes jemalloc configuration, but check the Dockerfile and image actually used by your application, especially after upgrades or customizations.

On Linux systems using glibc's allocator, setting `MALLOC_ARENA_MAX=2` limits the number of allocation arenas and may reduce memory usage. It can also affect allocation performance. This setting is specific to glibc and is not a general Ruby memory option.

Compare allocator changes under sustained load. Reduced fragmentation does not fix application code that unnecessarily retains objects.

Measuring Performance
---------------------

### Choosing a Workload

Test in an environment that resembles production, including CPU and memory limits, Ruby version, database capacity, and application configuration. A development-machine test describes that machine's behavior and may lead to different settings.

Begin with a few representative endpoints, including requests that exercise the database and any important external services. Use realistic data volumes, authentication, and cache behavior. Expand the workload to reflect the request mix and traffic levels you expect in production.

Run the load generator on a separate machine where possible, and verify that it has enough capacity to drive the test. Otherwise, the generator may become the bottleneck or compete with the application for resources.

### Recording a Baseline

Record the application version, configuration, workload, and infrastructure for each run. Measure:

* Successful requests per second, along with errors and timeouts.
* Median latency (P50) and tail latency (such as P95 or P99).
* CPU utilization and any CPU throttling.
* Memory usage during warmup and sustained load.
* Database connection usage and pool wait times.

A [percentile](https://en.wikipedia.org/wiki/Percentile_rank) describes the distribution of request times. P95 is a latency at or below which approximately 95% of measured requests complete; approximately 5% take longer. P50 is the median, while P95 and P99 describe the slower tail. Average latency alone can hide these slow requests.

Measure latency at the load generator or another appropriate client boundary. Rails' request log timing does not include every source of delay, such as queuing before Rails begins processing a request or network transit.

### Running a Load Test

Use a dedicated load-testing tool to reduce the risk of measurement errors. Choose one that reports successful throughput, errors, timeouts, and latency percentiles, and lets you control the workload and test duration.

Begin by exercising a representative endpoint in your test environment.

Check response status and content so redirects or errors do not appear to be successful application work. This single-endpoint test is a starting point, not a complete simulation of production traffic.

Short tests can provide an initial comparison, but longer tests are needed to observe memory growth, garbage collection patterns, and changes under sustained load. Collect enough requests for the tail percentiles you intend to compare.

NOTE: Tools that maintain a fixed number of connections can generate fewer requests as responses slow down, masking the effect of continued arrivals. To test a specified arrival rate, use a tool that can schedule new requests independently of response completion, and verify that the generator achieves the intended rate.

### Warmup

Warm up the application before recording results so connection establishment, caches, and runtime optimizations can settle. Discard warmup measurements. To check whether the warmup is sufficient, repeat the test with progressively longer warmup periods while keeping the measured workload and duration unchanged. Further warmup should no longer materially change throughput or latency beyond normal run-to-run variation. Then repeat measured runs to check consistency. Restart and warm up again after changing settings that require a restart.

### Testing Capacity and Headroom

After establishing a baseline, increase the offered request rate in steps while keeping the request mix consistent. Hold each step long enough to observe steady behavior, recording the offered rate as well as successful throughput, latency, errors, and resource usage. Identify where the deployment first exceeds your performance targets and investigate which resource is limiting it. Repeat the test for configurations you want to compare.

Treat capacity as the load the deployment can sustain while meeting those targets, rather than its highest observed requests-per-second value. Also test short traffic bursts and check that latency and queues recover after load falls. A brief successful run does not establish that memory usage or performance will remain stable under sustained traffic.

Leave **headroom** between expected peak traffic and measured capacity. For example, if a representative test meets your targets at 150 requests per second but fails them at 175, an expected peak of 150 leaves no demonstrated margin. Test enough additional capacity to accommodate plausible bursts, workload changes, and reduced availability while instances restart or deploy. There is no universal headroom percentage; choose and verify a margin appropriate to your traffic and deployment behavior.

Test the relevant deployment size and shared dependencies. Doubling application instances does not necessarily double capacity if they use the same constrained database or external service.

Tuning the Configuration
------------------------

### Comparing Settings

Keep the workload and test conditions consistent while changing one setting at a time. For example, compare these configurations:

| Configuration      | Workers | Threads per worker |
| ------------------ | ------: | -----------------: |
| Baseline           |       2 |                  3 |
| Additional threads |       2 |                  5 |
| Additional workers |       4 |                  3 |

Use the startup command shown earlier with the corresponding environment values. Ensure the database pool can accommodate each test and that the additional workers fit within the CPU and memory budget. If another setting must change, record it as part of the configuration being compared.

Compare successful throughput, median and tail latency, errors, and resource usage across repeated runs. A throughput increase is useful only if latency and reliability remain acceptable. Small differences within normal test variation are not sufficient evidence of an improvement.

### Investigating Constraints

Measurements provide clues about what to investigate:

| Observation                               | Possible causes to investigate                                                     |
| ----------------------------------------- | ---------------------------------------------------------------------------------- |
| High CPU utilization and rising latency   | Ruby execution, GVL contention, garbage collection, or insufficient CPU capacity   |
| Low CPU utilization and high latency      | Database or external-service waits, connection pool contention, or request queuing |
| Rising memory usage                       | Additional workers, live-object growth, allocation pressure, or fragmentation      |
| Increasing database pool wait times       | Insufficient pool capacity, long-held connections, or slow queries                 |
| Higher throughput with worse tail latency | Increased contention or queuing                                                    |

These observations are not definitive diagnoses. For example, low CPU utilization does not establish that more threads will help: the database or an external service may already be saturated. Investigate the limiting resource before increasing concurrency.

### Comparing Production Traffic

With multiple application instances, you can compare configurations under live traffic. Start with a limited group and use monitoring to compare latency, errors, throughput, and resource usage.

Keep infrastructure and traffic comparable between groups. Differences in routing, endpoint mix, cache state, or traffic volume can distort the results. Monitor database and external-service effects as well, since both groups may share these dependencies. Retain a way to restore the previous configuration if performance deteriorates.

Choose settings that meet your latency and throughput requirements while leaving resource capacity for traffic variation and deployments. Revisit them as the application, runtime, or workload changes.
