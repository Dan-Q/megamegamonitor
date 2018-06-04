# MegaMegaMonitor

## History

In 2014 I wrote a handful of [userscripts](https://en.wikipedia.org/wiki/Userscript) to enhance my enjoyment of [Reddit](https://www.reddit.com/).
This included a tool that monitored the membership of a number of private subreddits of which I was a contributor and 'tagged' other members' names
wherever I saw them on Reddit: i.e. it made it easier for me to spot my friends from private subs when I saw them "in the wild" of the rest of
Reddit. I made it available to the members of a particular private sub and, when it proved popular, started adding additional features such as the
ability to hide encrypted messages within our comments that would be automatically decrypted and shown to other members of the same private sub.

In 2015 I made the tool, which I called MegaMegaMonitor, generally-available via the domain name megamegamonitor.com, and promoted/discussed it and
its future on the [/r/megamegamonitor](https://old.reddit.com/r/megamegamonitor) subreddit. I added features to support the comprehension of the
"MegaLounge chain", monitor gildings, and assist with the moderation/membership-management of "gold"-style subs.

It quickly became apparent that the model I'd produced for a tool that was originally "just for me" was thoroughly underequipped to scale-up, and
began work on a replacement, which was only ever partially-implemented and some users continued to use the old version right up until the end. The
new version wasn't that solid, either, to be fair, and I wasn't able to give it the time or energy that it deserved.

In 2018, I closed down the MegaMegaMonitor backend service and let the domain name lapse. This code repository represents a large selection of the
final code for the project, presented in case anybody wants to refer to it or even continue or make a similar tool in the future (but read the
caveat below!).

## Why You Shouldn't Use This Code

This code is apalling. I mean: it's really, really bad. It's hacks on top of hacks, untested, and clearly shows at every stage that it was only ever
supposed to be a bit of Javascript for my own use. If you want to re-create MegaMegaMonitor, you should start not from here but from scratch.

Also; I've had to strip out a few bits of code to put it online here. So it won't work "out of the box"; not even a little.

## What's Here?

* schema-and-sample-data.sql - the final database schema, plus limited sample data to show how it worked
* 12x - the last release of the original public MegaMegaMonitor; the backend is powered by PHP
* 15x - the last release of the rewritten MegaMegaMonitor; the backend is powered by Ruby on Rails

## How Did MMM Work?

The "frontend" of MegaMegaMonitor was a browser plugin, implemented as a userscript for maximum cross-compatibility. It adds a snippet of Javascript
to every Reddit page that provides the functionality (it's implemented in Coffeescript and compiled/minified to produce the final output).

The frontend authenticates to the backend using Reddit authentication, at which point it's given an "accesskey" token that it uses for future
authentications. The accesskey is stored in localStorage (associated with the username, so it's usable by multiple Redditors on one computer). The
frontend authenticates with the backend to get a copy of the data it needs to present icons, decryption etc. to the user. It caches all of this in
localStorage and checks for updates periodically or when requested by the user.

The backend stores a copy of subreddit memberships, among other things, for delivery to the frontend plugin. Why use a backend? Reddit's API
dramatically limits the rate of requests tolerated, and so asking the frontend to load and store the names of hundreds or thousands of Redditors who
are in each of dozens of different subreddits is a painful experience, especially if it's to be updated daily. It also represents a huge duplication
of effort if multiple people are doing exactly the same operation. So instead the backend server does this in its "spare time" and saves a copy of
the membership lists of each monitored sub, and then delivers it to the frontend (but only to users whom it knows are members of those subs). This
means that the data isn't necessarily always up-to-date (and can be a day or so "stale") but the plugin works rightaway rather than having to spend
a long time preloading all of the requisite data.

v12x used to pre-generate output JSON for each permutation of sub membership, the thinking being that this would allow virtually-instantaneous
downloading by the frontend and reduce server load; however as the number of subs monitored expanded this resulted in exponential growth of the
number of cached files generated and this outweighed the benefits. v15x generated JSON on-demand and (with a little optimisation of the SQL)
this was a far more-satisfactory solution.

## Database Schema

Here's what you'll find in the database:

### accesskeys

Every user has one or more accesskeys (they get one for each browser/computer they connect from, and they get a new one if they clear their
localStorage). They're a long random string used to authenticate with the backend after the first time (i.e. a magic cookie).

### accounts

Because the backend needs to be able to log in to Reddit and get subreddit contributor lists, among other things, it needs usernames and passwords
for a number of Reddit accounts. In production, it used three: /u/avapoet (me!), /u/MegaMegaMonitorBot (a 'bot' account that mods could invite
to their sub to allow MMM to index their membership list without inviting me), and a third account belonging to a Redditor who'd gained access
to certain exclusive subs that would not allow either me nor the bot in but whose members wanted to be able to use MegaMegaMonitor; this Redditor
kindly donated their (secondary) account to the project. No credentials are included, of course, so you'll need to add your own.

### contributors

A list of known contributors to (members of) each monitored private sub. The backend performed partial updates (just spotting who was "new") most
days but more-intensive "full" updates (which included spotting people who'd been removed) once in a while.

### cryptokeys

Each monitored sub could be assigned one or more cryptokeys, with the most-recent being "current". These were used by the frontend to encrypt
messages then visible only by other members of that sub (and, of course, the backend would only give copies of cryptokeys for a sub to people
authenticated as users known to be members of that sub). Adding new keys periodically helped protect against continued access to future
plaintexts by users removed from a sub (they'd at most be able to read things encrypted with older, non-current cryptokeys). There's also a
cryptokey for "all MMM users", which is hard-coded and does not rotate (what would be the point, given that anybody can become an MMM user?).

### gildings

The backend also monitored who was gilded, when, and where, to streamline a variety of operations.

### schema_migrations

This is Rails magic for managing schema migrations.

### subreddits

The subreddits list is automatically populated with the list of private subs for which each account is a contributor. A secret backend (protected
using webserver configuration) allowed my management of the subreddit list, e.g. specifying which to monitor and for what, assigning an icon, etc.

### users

People who've installed MMM (at some point), when they were last seen to use it, and so on. There's also functionality in there to manage whether
members of NinjaLounge/PirateLounge are "in colours" (visible to members of the rival lounge) or not, but this was broken by the
NinjaLounge/TheNinjaLounge fork and I didn't have the emotional energy to keep making code changes to work around subreddit drama, so it stayed
broken.

## Don't Forget:

Don't use this code. Seriously, just don't.
