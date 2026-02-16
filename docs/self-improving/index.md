# Build a self-improving application

Develop an application that can enhance/bugfix, test and deploy itself.

!!! example "Example 1"

     - send a voice message to Clarabot: "Hey Clarabot, you already support WhatsApp and Telegram messaging. Please develop support for XMPP."
     - Clarabot does its own research. 
         - Checks out `fabiang/xmpp` but that seems abandoned. 
         - It then chooses `norgul/xmpp-php`. 
     - It forks the repo and develops a PHP8+ version with better support for Laravel &rarr; `[my-clarabot]/channel-xmpp-laravel`.
     - It then add this new library to the `composer.json` of its own `develop` branch and wraps/implements all the APIs Clarabot expects from a messaging/channel plugin.
     - It writes a set of tests, fixes bugs until all tests are OK and submits a PR to the original repo.
     - the PR gets merged to the staging version of the site and is tested even more with real channel traffic.
     - the PR gets merged to the production version of the site and is auto-deployed to the actual running Clarabot.
     - if the deployment would fail for some reason, Clarabot will automatically roll back to the previous version and send a message to the developer to fix the issue.
     - if no issues, Clarabot now supports XMPP messaging.

!!! example "Example 2"

     - send a voice message to Clarabot: "I want you to integrate my (Blaupunkt) Bluebot vacuum robot, so you can control it remotely."
     - Clarabot does its own research. 
         - It finds the IP address of the Bluebot device. It sends some HTTP requests to the device to get its current status.
         - it looks for an existing PHP library, but there is none.
         - it looks for an existing library in any langfauge (Python, Go, Rust ...), but there is none.
         - it finds the Bluebot mobile app on the Google Play site.
         - it runs the app in Android on Dokcer adb and captures the HTTP requests it sends to the Bluebot device.
     - it writes a PHP library that implements the HTTP API.
     - It writes a set of tests, fixes bugs until all tests are OK and submits a PR to the original repo.
     - the PR gets merged to the staging version of the site and is tested even more with real channel traffic.
     - the PR gets merged to the production version of the site and is auto-deployed to the actual running Clarabot.
     - if the deployment would fail for some reason, Clarabot will automatically roll back to the previous version and send a message to the developer to fix the issue.
     - if no issues, Clarabot now supports Bluebot vacuum robots.
