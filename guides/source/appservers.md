Guide To Choosing A Ruby App Server
===========
This guide will review what a web server and app server are, the difference between them, why you need an app server, discuss various security concerns, and then compare and contrast different properties of the most common app servers.

Web Servers
-------
The traditional way to serve sites on the Internet is via a *web server*, for example using Apache or Nginx. Apache is more broadly used and has more features, while Nginx is smaller, faster, and has fewer (but newer) features. Web Servers serve static files (those that sit on the server) and send requests on to other servers or programs. Web apps, such as those written in PHP or Ruby, generate content based on your code. An app server allows your web server to efficiently send requests to your web app, and to receive the content your web app generates.

Neither Apache nor Nginx can serve Ruby web apps straight out-of-the-box. This functionality is provided by an application server. The demands on your server are very different in a development vs production environment, with production requiring significantly higher performance and security than during development. Therefore for production use it is recommended to use a combination of a web server and an app server. They can cooperate by setting up the web server as a *reverse proxy* in front of the app server, or in the case of Passenger by directly plugging the app server into the web server. A reverse proxy setup means that the web server accepts an incoming HTTP request (a request for a webpage) and forwards it to the app server, which also speaks HTTP. The app server sends the HTTP response (the webpage content generated using your code) back to Apache/Nginx, which will forward the response back to the client (e.g. a web browser).

Despite being able to respond to HTTP requests an app server usually shouldn’t be allowed to directly accept HTTP requests from the internet because they don’t have sufficient concurrency to handle high traffic, adequate security to deal with malicious requests, and raw performance when serving static files. This will be covered in greater detail in the following sections.

App Servers
-------

### WEBrick
WEBrick is included in Ruby by default, and was the default Ruby *application server* in Rails until Rails 5. It offers basic app server functionality, which is to load your Ruby app and allow users to interact with it via HTTP. In concrete terms this means that WEBrick:

- Loads your Ruby app inside its (WEBrick’s) own process space.
- Sets up a TCP socket, which allows WEBrick to communicate with the outside world (e.g. the Internet).
- Listens for HTTP requests on this socket and passes the request data to the Ruby web app, which then returns an object that describes what the HTTP response should be.
- Converts the potential HTTP response to an actual HTTP response (the actual bytes) and sends it back over the socket to the outside world.

WEBrick is not suitable for production use. It is missing several important features, such as clustering and process monitoring; it is not robust (it has some known memory leaks and some known HTTP parsing problems); and it is written entirely in Ruby which impacts performance (most other Ruby app servers are written partly in Ruby and partly in C/C++). It was only intended to be used during development.

### Alternative App Servers
There are many additional app servers available today, the most popular are: Passenger, Puma, Rainbows!, Thin, TorqueBox, Trinidad, and Unicorn. Each app server will be described in a later section, and how they differ from each other. Mongrel is unmaintained and shouldn’t be used, so we will only describe its spiritual successors.

The App Server and the World
-------

All current Ruby app servers speak HTTP; however, some app servers may be directly exposed to the Internet, while others, for security reasons, may not. App servers which are not safe to expose to the Internet must be put behind a reverse proxy web server like Apache or Nginx, for reasons that will be explained below.

#### App servers that can be directly exposed to the Internet:
- Passenger
- TorqueBox
- Trinidad

#### App servers that should not be directly exposed to the Internet:
- Puma
- Rainbows!
- Thin
- Unicorn

### Why must some app servers be put behind a reverse proxy?
One reason is to be able to handle more than one request at a time. Some app servers can only handle one request at a time per process. If you want to handle multiple requests concurrently you need to run multiple app server instances, each serving the same Ruby app. This set of app server processes is called an app server cluster (hence the names “Mongrel Cluster”, “Thin Cluster”, etc). You must then configure a webserver such as Apache or Nginx to reverse proxy to this cluster. Apache/Nginx will take care of distributing requests between the instances in the cluster (this is explained further in the section titled "I/O concurrency models").

Another reason is security. Using Apache or Nginx in front of your app server is good security practice, because they are very mature and can shield the app server from (perhaps maliciously) corrupted requests.The web server can also buffer requests and responses, protecting the app server from "slow clients" - HTTP clients that don't send or accept data very quickly. You don't want your app server to do nothing while waiting for the client to send the full request or to receive the full response, because during that time the app server could be serving a different request. Apache and Nginx are very good at concurrency because they can be configured to operate in either [multithreaded](https://en.wikipedia.org/wiki/Thread_(computing)) or [evented](https://www.nginx.com/blog/inside-nginx-how-we-designed-for-performance-scale/) fashion. Puma has good protection against slow clients in most cases, however it doesn’t protect websockets connections, and it doesn’t serve static files as quickly as a dedicated web server which is why it was placed on this list.

A third reason is performance. Most app servers can serve static files, but are not particularly good at doing it quickly, whereas Apache and Nginx can do it faster. People typically set up Apache/Nginx to serve static files directly, and forward requests that don't correspond with static files to the app server. A good example is Rainbows! The author publicly stated that it's safe to directly expose it to the Internet because he is confident that there are no vulnerabilities in the HTTP parser (and similar code), however it [cannot compete with Nginx](http://bogomips.org/rainbows/Static_Files.html) in terms of raw performance serving static files.

### Why can some app servers be directly exposed to the Internet?
Usually these are app servers that reuse or integrate with battle-tested code and thereby benefit from the protection and features of these web servers. For example, Passenger integrates directly into the Apache and Nginx web servers, whereas Torquebox and Trinidad are both integrated into or based on the widely used Apache Tomcat, and are therefore considered safe to expose to the Internet.


Application Servers Compared
--------
### Passenger
Passenger integrates directly into Apache or Nginx, similar to mod_php for Apache. Just like mod_php allows Apache to serve PHP apps, Passenger allows Apache or Nginx to easily serve Ruby apps. Passenger has been designed with an emphasis on stability, reliability and ease-of-use. These qualities are enabled by its out-of-process architecture, its integrated buffering reverse proxy and a powerful set of administration tools. By virtue of its architecture Passenger is able to self-monitor and deal with failures in a robust way, as well as support multiple different programming languages and frameworks. Passenger’s integrated buffering reverse proxy both shields it from slow client attackers and generally improves performance. Passenger is written primarily in C++, and uses a hybrid evented I/O model, and as a result it scales well and has great performance.
### Passenger Enterprise
Passenger Enterprise is a paid version of Passenger; with extra features such as live debugging, automated rolling restarts, multithreading support, and deployment error resistance.
### Puma
Puma was forked from Mongrel, and has seen extensive improvement since. While Puma is fast, it is recommended to  use a reverse proxy to speed up static file serving. Puma was intended to be a purely multithreading app server but has also gained a cluster mode for multiprocessing. Puma is the default app server in Rails as of Rails 5, replacing WEBrick.
### Rainbows!
Rainbows! supports multiple concurrency models through the use of different libraries. Rainbows! is based on Unicorn, but designed to handle applications that expect long request/response times and/or slow clients. Because it offers so many different concurrency models, quite a bit of load testing is required to determine the best configuration for your app.
### Thin
Thin uses the evented I/O model by utilizing the EventMachine library. Other than using the Mongrel HTTP parser, it is not based on Mongrel in any way. Its cluster mode has no process monitoring so you need to monitor crashes etc. There is no Unicorn-like shared socket, so each process listens on its own socket. In theory, Thin's I/O model allows high concurrency, but in most practical situations that Thin is used for, each Thin process can only handle one request at a time, so you still need a cluster. (Learn more about this peculiar property in the section titled "I/O concurrency models".)
### Torquebox
Torquebox is fast once the JVM has warmed up but, because it is based on Apache Tomcat, it requires that you have a Java runtime installed and that you use JRuby. As far as Tomcat-based app servers go, Torquebox is better supported than others (it is backed by RedHat) and has far more features, such as easy database connections via JDBC, and a built in job runner. TorqueBox version 4, which supports JRuby 9000 (Ruby 2.2 compatible, which is required for the latest Rails), has been in development since mid 2014, and a stable version still hasn't been released.
### Trinidad
Trinidad is similar to Torquebox in that it is based on Apache Tomcat. However, it is not backed by a large well financed corporation; and, like Torquebox, it lacks a stable release that supports JRuby 9000 (Trinidad 1.5 has been in beta since 2014).
### Unicorn
Unicorn is a fork of Mongrel. It supports limited process monitoring: If a process crashes it is automatically restarted by the master process, it is also able to perform a zero-downtime update to your app in some cases. It can make all processes listen on a single shared socket, instead of a separate socket for each process. This simplifies reverse proxy configuration. Like Mongrel, it is purely single-threaded multi-process. However unicorn is [highly inefficient](https://unicorn.bogomips.org/PHILOSOPHY.html#label-Just+Worse+in+Some+Cases) for Comet/SSE/reverse-HTTP/push applications where the HTTP connection spends a large amount of time idle.

App Servers by Feature
-------
### Multi-Ruby-Support:
Puma and Passenger support many Rubies: MRI, JRuby, and Rubinius. Unicorn and Thin only support MRI. Torquebox and Trinidad only support JRuby.
### Polyglot (Multi-Language) Servers:
Passenger supports Python WSGI and Node.js in addition to Ruby. Both Trinidad and Torquebox support Java in addition to Ruby.
### Out-Of-Band Garbage Collection
Passenger can run the Ruby garbage collector(https://en.wikipedia.org/wiki/Garbage_collection_(computer_science)) when it is not handling a request from a client, potentially reducing request times by hundreds of milliseconds. Unicorn has a similar feature, although contrary to Passenger’s version it cannot be used for arbitrary work (limited to GC) and does not work well with multithreaded apps.
### Documentation
Passenger, Torquebox, and Trinidad have good documentation coverage. Thin, Puma, and Unicorn only have minimal documentation.

I/O Concurrency Models
-------
I/O is the task of reading or writing data from or to any device that is not directly on the CPU. It is orders of magnitude slower than non-I/O tasks and therefore involves the processor waiting for the I/O task to complete. Because of this waiting a large amount of I/O can potentially be done concurrently, as the CPU doesn’t have to do extra work while additional I/O tasks wait.
### Single-Threaded Multi-Process
This is traditionally the most popular I/O model for Ruby app servers, partially because many gems were not thread safe for a long time. Each process can handle exactly one request at a time. The web server load-balances between processes. This model is very robust and there is little chance for the programmer to introduce concurrency bugs. However, its I/O concurrency is limited by the number of processes, and its memory use is very high (each process contains an entire Ruby VM(https://en.wikipedia.org/wiki/Ruby_(programming_language)#Implementations) and application with all gems). This model is suitable for fast, short-running workloads. It is however unsuitable for slow, long-running blocking I/O workloads, e.g. workloads involving the calling of HTTP APIs.
### Purely Multi-Threaded
Nowadays the Ruby ecosystem has excellent multithreading support, so this I/O model has become very viable. Multithreading allows high I/O concurrency, making it suitable for both short-running and long-running blocking I/O workloads. The programmer is more likely to introduce concurrency bugs, but luckily most web frameworks are designed in such a way that makes this very unlikely. One thing to note however is that the MRI Ruby interpreter cannot leverage multiple CPU cores even when there are multiple threads, due to the use of the Global Interpreter Lock (GIL). You can work around this by using multiple multi-threaded processes, because each process can leverage a CPU core. JRuby and Rubinius have no GIL, so they can fully leverage multiple cores in a single process, so as to fully use the hardware you are paying for.
### Evented
This model is completely different from the previously mentioned models. It allows very high I/O concurrency and is therefore excellent for long-running blocking I/O workloads. To utilize it, explicit support from the application and the framework is required. Unfortunately, none of the major frameworks (Padrino, Rails, Sinatra, etc.) support evented code. This is why even though Thin supports the evented I/O model, in practice each process still cannot handle more than one request at a time, since it still has to operate with the framework.This means that Thin effectively operates with a single-threaded multi-process model.

There are some specialized frameworks that can take advantage of evented I/O, such as Cramp. However, being less popular, there is less support from the community and fewer gems available.
### Hybrid Evented/Multithreaded/Multiprocess
This I/O model is primarily implemented by Passenger Enterprise (version 5 or later). You can easily switch between single-threaded multi-process, purely multithreaded, and multiple processes each with multiple threads. Passenger Enterprise's HTTP server spawns as many threads as there are CPU cores, and runs an event loop on each thread. An internal load balancer allows it to accept new clients and distribute requests evenly over all threads in an ordered top-down first available manner. Your app runs in a process pool, with each process having a configured number of threads.

Puma uses a similar version of this model when running in cluster mode, but it is limited (it only has one process spawning mode and does not support JRuby) and requires you to configure Puma more extensively.

Performance
--------
### Your bottleneck is most likely elsewhere
When discussing Ruby app server performance, it is important to keep a few things in mind. Ruby is slow, but that's usually okay because I/O is much slower. For example, if your Ruby web app talks to a database or receives a network request then in most cases the time spent there  already eclipses the time your web app will take performing non-I/O tasks. A similar principle is true for app servers. Even a slow app server will likely be much faster than your Ruby app, so app server performance is mainly a factor once you are serving very large numbers of users simultaneously. No app server will speed up a slow app. A server can only provide tools to work around that slowness, such as caching, load balancing, multiple threads and/or processes, load balancing, and request timeouts, but you will always see the best returns by speeding up your app (which generally means reducing I/O). If, after profiling (measuring the speed of all the pieces involved in serving requests, in a controlled and scientific manner), you find that a significant proportion of your request latency (time taken before responding) is due to your app server, that is when you should consider choosing a faster app server.
### Scaling
There are two constraints to keep in mind when talking about scaling (serving more requests at the same time). First, the available RAM (memory); and second, the speed and number of CPU cores. The more resources you have, the bigger you can scale. In Ruby apps, the RAM usage is almost always the source of the bottleneck that prevents scaling bigger. The amount of RAM being used boils down to your webapp and which I/O model you are using. Adding threads requires less additional RAM than adding processes, so a multithreaded app server will usually minimize the RAM usage the most, and therefore will allow the biggest scale.

Passenger Enterprise, Puma, Rainbows! (using a multithreading concurrency model), Torquebox, and Trinidad are all multi-threaded servers which will scale similarly, so for large deployments these are your best options. To choose between them you must decide which features are important to you, which is very specific to your situation. Please see the table below as a reference.

Comparison Chart
--------

| App Server | Ease of Use | Multithreading | Requires Reverse Proxy | Stable Release | Free | Offers Support | Other Notable Points |
|------------|-------------|----------------|------------------------|----------------|------|----------------|----------------------|
|Passenger | ✔ | ✗ | ✗ | ✔ | ✔ | * | *Available for purchase |
|Passenger Enterprise | ✔ | ✔ | ✗ | ✔ | ✗ | ✔ | Has great debugging tools|
|Puma | ✗ | ✔ | ✔ | ✔ | ✔ | ✗ | Default Rails Server|
|Rainbows! | ✗ | ✔ | * | ✔ | ✔ | ✗ | *Sometimes|
|Thin | ✗ | ✗ | ✔ | ✔ | ✔ | ✗ | Rails doesn’t use event model|
|Torquebox | ✗ | ✔ | ✗ | ✗ | ✔ | ✗ | Uses the JVM|
|Trinidad | ✗ | ✔ | ✗ | ✗ | ✔ | ✗ | Uses the JVM|
|Unicorn | ✗ | ✗ | ✔ | ✔ | ✔ | ✗ | Cannot handle long requests|

Conclusion
-------
This guide explained that in order to serve Ruby applications, you need an application server, usually in combination with a traditional web server. We compared WEBrick, Passenger, Puma, Rainbows!, Thin, TorqueBox, Trinidad, and Unicorn and examined various security and performance characteristics of each app server. In the end each app server brings something different and you may not need every feature. Depending on your specific web app’s needs, the volume of requests you need to handle, and the amount of time you are able to put into configuring your server there will be an app server that can keep you safe and handle everything that the internet can throw at it.
