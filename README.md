ZLTaskManager
=============

There are many ways to dispatch work with Objective-C, from [Grand Central Dispatch](http://www.raywenderlich.com/60749/grand-central-dispatch-in-depth-part-1) to [NSOperations](http://nshipster.com/nsoperation/) however, none of these approaches handle persisting work. ZLTaskManager fills this void. With this library we can persist work from app launch to app launch. We can make sure this work is retried again and again until it succeeds (or until we decide to stop retrying it, more on this later). And thanks to this we can start work without adding endless failsafes to make sure that it is done correctly.  
