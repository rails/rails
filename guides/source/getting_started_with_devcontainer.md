**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Getting Started with Dev Containers
===================================

After reading this guide, you will know:

* How to create a new Rails application with the `rails-new` tool.
* How to begin working with your application in a development container.

--------------------------------------------------------------------------------

The best way to read this guide is to follow it step by step. All steps are
essential to run this example application and no additional code or steps are
needed.

This guide helps you get set up with [development containers (or dev containers for short)](https://containers.dev/)
for a full-featured development environment. Dev containers are used to run your
Rails application in a container, without needing to install Ruby or Rails or its dependencies
directly on your machine. This is the fastest way to get your Rails application up and running.

This is an alternative to installing Ruby and Rails directly on your machine, which is
covered in the [Getting Started guides](getting_started.html#creating-a-new-rails-project).
Once you have completed this guide, you can continue building your application by following
the Getting Started guide.

Setup and Installation
----------------------

To get set up, you will need to install the relevant tools; Docker, VS Code and
`rails-new`. We'll go into details about each one below.

### Installing Docker

Dev containers are run using Docker, an open platform for developing, shipping, and
running applications. You can install Docker by following the installation instructions
for your operating system in the [Docker docs](https://docs.docker.com/desktop/).

Once Docker has been installed, launch the Docker application to begin running
the Docker engine on your machine.

### Installing VS Code

Visual Studio Code (VS Code) is an open source code editor developed by Microsoft. VS Code's Dev Containers
extension allows you to open any folder inside (or mounted into) a container and take advantage of
Visual Studio Code's full feature set. A [devcontainer.json](https://code.visualstudio.com/docs/devcontainers/containers#_create-a-devcontainerjson-file)
file in your project tells VS Code how to access (or create) a development container with a
well-defined tool and runtime stack. It allows you to quickly spin up containers, access terminal
commands, debug code, and utilize extensions.

You can install VS Code by downloading it from [the website](https://code.visualstudio.com/).

You can install the Dev Containers extension by downloading it from [the marketplace](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

### Installing rails-new

`rails-new` generates a new Rails application for you without having to install Ruby on
your machine. It uses Docker to generate the Rails application, thus allowing Docker to
take care of installing the correct Ruby and Rails versions for you.

To install `rails-new`, follow the installation instructions [in the README](https://github.com/rails/rails-new?tab=readme-ov-file#installation).

Creating the Store Application
------------------------------

Rails comes with a number of scripts called generators that are designed to make
your development life easier by creating everything that's necessary to start
working on a particular task. One of these is the new application generator,
which will provide you with the foundation of a fresh Rails application so that
you don't have to write it yourself. The `rails-new` tool uses this generator to
create a new Rails application for you.

NOTE: The examples below use `$` to represent your terminal prompt in a UNIX-like OS,
though it may have been customized to appear differently.

To use `rails-new` to generate your app, open a terminal, navigate to a directory where you have
rights to create files, and run:

```bash
$ rails-new store --devcontainer
```

This will create a Rails application called Store in a `store` directory.

TIP: You can see all of the command line options that the Rails application
generator accepts by running `rails-new --help`.

After you create the store application, switch to its folder:

```bash
$ cd store
```

The `store` directory will have a number of generated files and folders that make
up the structure of a Rails application. Most of the work in this tutorial will
happen in the `app` folder. For a full rundown of everything in your application
see the full [Getting Started guide](getting_started.html).

Opening the Store Application in a Dev Container
------------------------------------------------

Our new Rails application comes with a dev container already configured and ready to use.
We will use VS Code to spin up and work with our dev container. Start by launching VS Code
and opening your application.

Once the application opens, VS Code should prompt you that it has found a dev container
configuration file, and you can reopen the folder in a dev container. Click the green "Reopen
in Container" button to create the dev container.

Once the dev container setup is complete, your development environment is ready to use,
with Ruby, Rails, and all your dependencies installed.

You can open the terminal within VS Code to verify that Rails is installed:

```bash
$ rails --version
Rails 8.1.0
```

You can now continue with the [Getting Started guide](getting_started.html) and
begin building your Store application. You will be working within VS Code, which serves as
your entry point to your application's dev container, where you can run code, run tests, and
run your application.
