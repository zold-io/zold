<img src="http://www.zold.io/logo.svg" width="92px" height="92px"/>

[![Donate via Zerocracy](https://www.0crat.com/contrib-badge/CAZPZR9FS.svg)](https://www.0crat.com/contrib/CAZPZR9FS)

[![EO principles respected here](https://www.elegantobjects.org/badge.svg)](https://www.elegantobjects.org)
[![Managed by Zerocracy](https://www.0crat.com/badge/CAZPZR9FS.svg)](https://www.0crat.com/p/CAZPZR9FS)
[![DevOps By Rultor.com](http://www.rultor.com/b/yegor256/zold)](http://www.rultor.com/p/yegor256/zold)
[![We recommend RubyMine](https://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

[![Build Status](https://travis-ci.org/zold-io/zold.svg?branch=master)](https://travis-ci.org/zold-io/zold)
[![PDD status](http://www.0pdd.com/svg?name=zold-io/zold)](http://www.0pdd.com/p?name=zold-io/zold)
[![Gem Version](https://badge.fury.io/rb/zold.svg)](http://badge.fury.io/rb/zold)
[![Test Coverage](https://img.shields.io/codecov/c/github/zold-io/zold.svg)](https://codecov.io/github/zold-io/zold?branch=master)

[![Yard Docs](http://img.shields.io/badge/yard-docs-blue.svg)](http://rubydoc.info/github/zold-io/zold/master/frames)
[![Maintainability](https://api.codeclimate.com/v1/badges/2861728929db934eb376/maintainability)](https://codeclimate.com/github/zold-io/zold/maintainability)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/yegor256/takes/blob/master/LICENSE.txt)
[![Hits-of-Code](https://hitsofcode.com/github/zold-io/zold)](https://hitsofcode.com/github/zold-io/zold)

To understand what Zold cryptocurrency is about you may want
to watch [this video](https://youtu.be/5A9uBwMow0M) first. Then, you may
want to read [this blog](https://blog.zold.io/2018/07/08/mission.html) post.
Then, you have to read the [Green Paper](https://papers.zold.io/green-paper.pdf)
(just four pages). In a nutshell, Zold is a cryptocurrency with the following
features:

  * No Blockchain
  * No General Ledger
  * Very fast, because de-centralized
  * 100 times cheaper than Bitcoin
  * Proof-of-work
  * Unique consensus protocol
  * Pre-mined with total capacity of 2 billion ZLD
  * Anonymous
  * Written in Ruby

More details you can find in the [White Paper](https://papers.zold.io/wp.pdf).

You can also find us at the [Bitcointalk](https://bitcointalk.org/index.php?topic=5095078) forum.

Join our [Telegram group](https://t.me/zold_io) to discuss it all live.

## How to Use

You can try the web wallet [here](https://wts.zold.io), but the best way
to use Zold is through the command line tool, which has all the features
and should remind you Git, if you are a programmer.

First, install [Ruby 2.3+](https://www.ruby-lang.org/en/documentation/installation/),
[Rubygems](https://rubygems.org/pages/download), and
the [gem](https://rubygems.org/gems/zold).
Here is [how](https://github.com/zold-io/zold/blob/master/INSTALL.md).

To make sure it's installed, try:

```bash
$ zold --help
```

You will need RSA private and public keys in `~/.ssh`.
If you don't have them yet, run this in order to generate a new pair
(just hit <kbd>Enter</kbd> when it asks you for a password):

```bash
$ ssh-keygen -t rsa -b 4096
```

Then, create a new wallet (instead of `5f96e731e48ae21f` there will be your
personal wallet ID, use it everywhere below):

```bash
$ zold create
5f96e731e48ae21f
```

Then, push it to the network:

```bash
$ zold push 5f96e731e48ae21f
```

Then, give this ID to your friend, who is going to pay you.
When the payment is sent, ask him or her for the ID of the wallet
the payment has been sent from and then fetch that wallet
(let's say it is `5555444433332222`):

```bash
$ zold fetch 5555444433332222
5.00 ZLD added to 5f96e731e48ae21f: To my friend!
```

Now, you have the money in your wallet!

Next, you can pay your friend back:

```bash
$ zold pay 5f96e731e48ae21f 5555444433332222 2.50 'Here is a refund'
-2.50 ZLD added to 5f96e731e48ae21f: Here is a refund
```

Finally, you have to push your wallet to the network so that your friend
knows about the payment:

```bash
$ zold push 5f96e731e48ae21f
```

That's it.

## How to Start a Node

You also can contribute to Zold by running a node on your server.
In order to do that just run (with your own wallet ID, of course):

```bash
$ zold node --invoice=5f96e731e48ae21f
```

Then, open the page `localhost:4096` in your browser
(you may need to open the inbound port at your
[IP firewall](https://www.howtogeek.com/177621/the-beginners-guide-to-iptables-the-linux-firewall/)).
If you see a simple JSON document, everything is fine.
Next, hit <kbd>Ctrl</kbd>+<kbd>c</kbd> and run it again, but with `--nohup`:

```bash
$ zold node --nohup --invoice=5f96e731e48ae21f
```

Now you can close the console;
the software will work in the background, saving the output logs to `zold.log`.
The software will update itself automatically to new versions.
The software will never stop, even if it crashes internally with any error.
In order to terminate it forcefully, do:

```bash
$ killall -9 zold
```

Grateful users of the system will pay "taxes" to your wallet
for the maintenance of their wallets, and the system will occasionally
send you bonuses for keeping the node online (approximately 1 ZLD per day).

If you are lost, run this:

```bash
$ zold node --help
```

You can run a node in a docker container also, using [yegor256/zold](https://hub.docker.com/r/yegor256/zold)
built from this [Dockerfile](https://github.com/zold-io/zold/blob/master/Dockerfile).

```bash
docker run -d -p 4096:4096 yegor256/zold /node.sh --host=<your host IP> --invoice=5f96e731e48ae21f
```

To store zold data between container restarts create a volume or bind a directory from host:

```bash
docker volume create zold
docker run -d -p 4096:4096 -v zold:/zold yegor256/zold /node.sh --host=<your host IP> --invoice=5f96e731e48ae21f
```

You may find this blog post useful:
[How to Run Zold Node?](https://blog.zold.io/2019/01/10/how-to-run-node.html)

## If Your File System is on Fire (or How to Reduce Your Hard Disk Usage)

At the moment, the file system is utilised too aggressively and if you
like to calm this process down and have a bit of spare memory, you may
find the following approach handy (directly applicable to FreeBSD OS).

The application data can be moved to [a memory-backed memory disk](https://www.freebsd.org/doc/handbook/disks-virtual.html)
with a periodical syncing of `farm`, `zold.log` and `.zolddata` to the
hard disk.

The `/etc/fstab` entry:
```
md /usr/home/zold/app-in-mem mfs rw,-M,-n,-s512m,-wzold:zold,-p0755 2 0
```

The `/etc/crontab` entry:
```
*/10    *       *       *       *       zold    /usr/local/bin/rsync -aubv /usr/home/zold/app-in-mem/farm /usr/home/zold/app-in-mem/zold.log /usr/home/zold/app-in-mem/.zoldata /usr/home/zold/app/
```

## Frequently Asked Questions

> Is there a configuration file?

Any command line flag can also be put in the `~/.zold` file, one per line, e.g.:
```
--home=~/.zold_home
--verbose
```

> Where are my RSA private/public keys?

They are in `~/.ssh/id_rsa` (private key) and `~/.ssh/id_rsa.pub` (public key).
Make sure you have a copy of your private key in some safe place.
If you lose the public key, it's not a problem, since your wallet has it.
But the private key is your personal asset.
Anyone can use your wallet if they have the private key.
Keep it safe and secure!

> How to use my RSA private key from https://wts.zold.io?

Retrieve the key via https://wts.zold.io/key. It can then be used with
the command line flag `--private-key` (e.g., for the `pay`, `node` and
`taxes` commands).

If you need the public key, you can generate it with
`ssh-keygen -y -f .ssh/zold_key > .ssh/zold_key.pub`. It can then be used
with the command line flag `--public-key` (e.g., for the `create` command).

> What is the best way to check the balance of the rewards collected by nodes?

You just do `zold pull <Wallet_ID>` and the rewards (taxes) will be visible there.

> Can I setup multiple nodes with one wallet address?

Yes, you can run many nodes with the same wallet ID.

> Is there a way to increase the number of threads in order to maximize computing power of multiple core machines?

Yes, you can use `--threads` command line argument for your node
and the number of threads will be as big as you wish.

## Front-end JSON Details

When you open up the front web page of your node, you will see a JSON document
with a lot of technical details. Here is the explanation of the majority of them:

`version` is the current version of the running software.
The node is supposed to update update itself automatically (if you run it via `zold-nohup`)
every time it discovers another node with a higher version.

`network` is the name of the network the node belongs to.
The production network's name is `zold`.
For testing purposes you can start a node in a test network, using `--network=test`.

`score` is the current score your node is exposing to the network now.
All other nodes are using this information in order to decide how much
they can trust your node with the information it provides, about wallets.
The higher the score, the better.

  * `value` is the amount of suffixes the score contains; this is the
    number all other nodes rely on.

  * `host` is the host name of the node, it must be equal to the public
    IP or domain name of the node; it is provided in `--host` command line
    option of `zold-nohup`.

  * `port` is the TCP port number, which usually is equal to 4096;
    it is provided in `--port` command line option.

  * `invoice` is the address of your wallet, where the system
    will send you rewards for keeping the node online and some
    users will pay taxes; it is provided in `--invoice` command line option.

  * `time` is the ISO-8601 UTC date and time of when your node
    started to calculate the score.

  * `strength` is the amount of tailing zeros the hash contains.

  * `hash` is the SHA-256 hash of the score text.

  * `minutes` is the age of the score, in minutes since the moment
    it was created.

`pid` is the Unix process ID of the running software.

`cpus` is the amount of CPUs detected on the server.

`threads` is the amount of running threads vs. the total amount of
threads in the Ruby process. If the second number is over 100 there
is definitely something wrong with the software.

`wallets` is the total number of wallets managed by the server.
The bigger the number, the better. When the server starts, the number
is small and it starts growing when other nodes are pushing wallets
to your node.

`remotes` is the total number of remote nodes your node is aware of.
The bigger the number, the more "connected" your node is to the
network. You can see the full list of nodes at `/remotes` URL of your node.

`farm` is the score calculating software.

  * `threads` is the amount of threads this software module is using.
    This number is configured via the `--threads` command line option.
    The bigger the number, the more intensively the software will use
    your CPUs. It is recommended to make this number equal to the
    number of CPUs available.

  * `pipeline` is ... something not important to you.

  * `best` is the list of scores known to the farm at the moment (with their ages in minutes).

`entrance` is the place where all new wallets arive and get merged and pushed
further. The health of this point is critical to the entire node. Some
numbers it includes must be watched carefully.

To be continued...

`date` is the current date and time on the server.

`hours_alive` is the time in hours your server is alive without a reboot.

## HTTP RESTful API

Well, maybe it's not purely RESTful, but each node has a simple
set of HTTP entry points, which you can use to retrieve information
about wallets, node status, log details, and some other things. Here
is a more or less complete list of them:

  * `GET /`: returns the JSON explained above

  * `GET /score`: returns the text presentation of the current Score

  * `GET /version`: returns the version of the software

  * `GET /protocol`: returns the protocol ID

  * `GET /wallet/ID`: returns the JSON with wallet details

  * `GET /wallet/ID/balance`: returns wallet balance in zents (text/plain)

  * `GET /wallet/ID/key`: returns wallet public RSA key

  * `GET /wallet/ID/mtime`: returns ISO-8601 time of wallet file modification

  * `GET /wallet/ID/size`: returns the size of the wallet file in bytes

  * `GET /wallet/ID/age`: returns the age of the wallet, in seconds

  * `GET /wallet/ID/txns`: returns the amount of transactions in the wallet

  * `GET /wallet/ID/debt`: returns the tax debt of the wallet in zents

  * `GET /wallet/ID/digest`: returns SHA-256 digest of the wallet file

  * `GET /wallet/ID/mnemo`: returns the mnemo short string of the wallet

  * `GET /wallet/ID/txns.json`: returns the full list of transactions in the wallet in JSON document

  * `GET /wallet/ID.txt`: returns the text presentation of the wallet

  * `GET /wallet/ID.html`: returns the HTML presentation of the wallet

  * `GET /wallet/ID.bin`: returns the entire wallet file

  * `GET /wallet/ID/copies`: returns the list of copies of the wallet

  * `GET /wallet/ID/copy/NAME`: returns the entire content of a single copy of the wallet

  * `PUT /wallet/ID`: accepts a new content of the wallet, in order to
    modify the one stored on the server (PUSH operation)

  * `GET /wallets`: returns the list of all wallets maintained by the node,
    in plain text, separated by EOL

  * `GET /remotes`: returns the list of remote nodes in JSON

  * `GET /ledger`: returns the list of recently visible transactions

  * `GET /ledger.json`: returns the list of recently visible transactions, in JSON

There are a few other entry points, which exist most for debugging purposes,
they may not be supported by alternative implementations of the node software:

  * `GET /pid`: returns the process ID of the software

  * `GET /trace`: returns the entire log of the node

  * `GET /farm`: returns the statistics of the Farm

  * `GET /metronome`: returns the statistics of the Metronome

  * `GET /threads`: returns the statistics of all Ruby threads

  * `GET /ps`: returns the statistics of all currently running Unix processes

  * `GET /queue`: returns the statistics of the node queue

  * `GET /journal`: returns the journal, in HTML

  * `GET /journal/item?id=ID`: returns the content of a single journal entry

There could be other entry points, not documented here.

## SDK

Here is how you use Zold SDK from your Ruby app. First, you should
add `zold` [gem](https://rubygems.org/gems/zold)
to your [`Gemfile`](https://bundler.io/gemfile.html) or just:

```bash
$ gem install zold
```

Then, you will need a directory where wallets and other supplementary data will be kept.
This can be any directory, including a temporary one. If it doesn't exist,
it will automatically be created:

```ruby
home = '/tmp/my-zold-dir'
```

Then, you need to create three objects:

```ruby
require 'zold/wallets'
require 'zold/sync_wallets'
require 'zold/remotes'
wallets = Zold::SyncWallets.new(Zold::Wallets.new(home))
remotes = Zold::Remotes.new(File.join(home, 'remotes'))
copies = File.join(home, 'copies')
```

The first step is to update the list of remote nodes, in order
to be properly connected to the network:

```ruby
require 'zold/commands/remote'
Zold::Remote.new(remotes: remotes).run(['remote', 'update'])
```

Now you are ready to create a wallet:

```ruby
require 'zold/commands/create'
Zold::Create.new(wallets: wallets, remotes: remotes).run(
  ['create', '--public-key=/tmp/id_rsa.pub', '--skip-test']
)
```

Here `--public-key=/tmp/id_rsa.pub` points to the absolute location of
a public RSA key for the wallet you want to create.

You can also pull a wallet from the network:

```ruby
require 'zold/commands/pull'
Zold::Pull.new(wallets: wallets, remotes: remotes, copies: copies).run(['pull', '00000000000ff1ce'])
```

Then, you can make a payment:

```ruby
require 'zold/commands/pay'
Zold::Pay.new(wallets: wallets).run(
  ['pay', '17737fee5b825835', '00000000000ff1ce', '19.99', 'For a pizza', '--private-key=/tmp/id_rsa']
)
```

Here `--private-key=/tmp/id_rsa` points to the absolute location of the private RSA key of
the paying wallet.

Finally, you can push a wallet to the network:

```ruby
require 'zold/commands/push'
Zold::Push.new(wallets: wallets, remotes: remotes).run(%w[push 17737fee5b825835])
```

By default, all commands will work quietly, reporting absolutely nothing
to the console. To change that, you can use `log` argument of their constructors.
For example, `Zold::Log::Verbose` will print a lot of information to the console:

```ruby
require 'zold/commands/push'
Zold::Push.new(wallets: wallets, remotes: remotes, log: Zold::Log::VERBOSE).run(['push'])
```

Also, all commands by default assume that you are working in a `test` network.
This is done in order to protect our production network from your test cases.
In order to instruct them to deal with real data and real nodes, you should
give them `--network=zold` argument, for example:

```ruby
require 'zold/commands/push'
Zold::Push.new(wallets: wallets, remotes: remotes).run(%w[push 17737fee5b825835 --network=zold])
```

If anything doesn't work as explained above, please
[submit at ticket](https://github.com/zold-io/zold/issues) or join our
[Telegram group](https://t.me/zold_io) and complain there.

## How to Contribute

It is a Ruby command line gem. First, install
[Ruby 2.3+](https://www.ruby-lang.org/en/documentation/installation/),
[Rubygems](https://rubygems.org/pages/download),
and
[Bundler](https://bundler.io/).
Then:

```bash
$ bundle update
$ bundle exec rake
```

The build has to be clean. If it's not, [submit an issue](https://github.com/zold-io/zold/issues).

Then, make your changes, make sure the build is still clean,
and [submit a pull request](https://www.yegor256.com/2014/04/15/github-guidelines.html).

If some test fails and you need to run it individually,
check the logging configuration inside `test__helper.rb` and make
sure the `Verbose` log is assigned to `$log`. Then, run, for example:

```bash
$ ruby test/commands/test_node.rb
```

If you need to run a single test method, do this:

```bash
$ ruby test/test_wallet.rb -n test_adds_transaction
```
