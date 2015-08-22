**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

Concerns
========

So what exactly is a concern, and what do you do with the concerns folders in /controllers and /models ?

After reading this guide, you will know:

* What a concern is
* What the /concerns folders are meant to contain
* Why your concern might not be working

---------------------------------------------------------------

Why Use Concerns?
----------------------

A concern is essentially a module that contains methods you would like to be able to use for multiple controllers or actions. They are a good way to keep your controllers and models small and keep your code DRY.
You can use it in your controller or model the same way you would use any module.


Quick Guidelines / Troubleshooting
----------

* Write concerns only for methods you find yourself using in multiple models/controllers. In the case of a controller,if you wish to make one smaller but its methods are not used anywhere else, you can use the automatically generated helper files in app/helpers instead.

* A newly generated app usually contains `app/models/concerns` and `app/controllers/concerns` in its `autoload_paths` so that it is accessible to the app. If your app is having trouble finding your concern module, you may need to check your `autoload_paths'.
 You can learn about how to do so <a href='http://guides.rubyonrails.org/autoloading_and_reloading_constants.html#autoload-paths'>here</a>.

