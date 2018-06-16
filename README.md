<img src="http://www.zold.io/logo.svg" width="92px" height="92px"/>

[![EO principles respected here](http://www.elegantobjects.org/badge.svg)](http://www.elegantobjects.org)
[![Managed by Zerocracy](https://www.0crat.com/badge/CAZPZR9FS.svg)](https://www.0crat.com/p/CAZPZR9FS)
[![DevOps By Rultor.com](http://www.rultor.com/b/yegor256/zold)](http://www.rultor.com/p/yegor256/zold)
[![We recommend RubyMine](http://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

[![Build Status](https://travis-ci.org/zold-io/zold.svg)](https://travis-ci.org/zold-io/zold)
[![Build status](https://ci.appveyor.com/api/projects/status/15ola3lb03opv14m?svg=true)](https://ci.appveyor.com/project/yegor256/zold-wcn4o)
[![PDD status](http://www.0pdd.com/svg?name=zold-io/zold)](http://www.0pdd.com/p?name=zold-io/zold)
[![Gem Version](https://badge.fury.io/rb/zold.svg)](http://badge.fury.io/rb/zold)
[![Test Coverage](https://img.shields.io/codecov/c/github/zold-io/zold.svg)](https://codecov.io/github/zold-io/zold?branch=master)

[![Maintainability](https://api.codeclimate.com/v1/badges/7489c1d2bacde40ffc09/maintainability)](https://codeclimate.com/github/zold-io/zold/maintainability)

**NOTICE**: It's an experiment and a very early draft! Please, feel free to
submit your ideas and/or pull requests.

Here is the [White Paper](https://github.com/zold-io/papers/raw/master/wp.pdf).

Join our [Telegram group](https://t.me/zold_io) to discuss it all live.

The license is [MIT](https://github.com/zold-io/zold/blob/master/LICENSE.txt).

## How to Use

First, install [Ruby 2.3+](https://www.ruby-lang.org/en/documentation/installation/),
[Rubygems](https://rubygems.org/pages/download), and
the [gem](https://rubygems.org/gems/zold).
Here is [how](https://github.com/zold-io/zold/blob/master/INSTALL.md).

To make sure it's installed, try:

```bash
$ zold --help
```

You will need PGP private and public keys in `~/.ssh`.
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

Grateful users of the system will pay "taxes" to your wallet
for the maintenance of their wallets, and the system will occasionally
send you bonuses for keeping the node online (approximately 1 ZLD per day).

## Frequently Asked Questions

> Where are my PGP private/public keys?

They are in `~/.ssh/id_rsa` (private key) and `~/.ssh/id_rsa.pub` (public key).
Make sure you have a copy of your private key in some safe place.
If you lose the public key, it's not a problem, since your wallet has it.
But the private key is your personal asset.
Anyone can use your wallet if they have the private key.
Keep it safe and secure!

> What is the best way to check the balance of the rewards collected by nodes?

You just do `zold pull <Wallet_ID>` and the rewards (taxes) will be visible there.

> Can I setup multiple nodes with one wallet address?

Yes, you can run many nodes with the same wallet ID.

> Is there a way to increase the number of threads in order to maximize computing power of multiple core machines?

Yes, you can use `--threads` command line argument for your node
and the number of threads will be as big as you wish.

## JSON Details

When you open up the front web page of your node, you will see a JSON document
with a lot of technical details. Here is the explanation of the majority of them:

`version` is the current version of the running software.
The node is supposed to update update itself automatically (if you run it via `zold-nohup`)
every time it discovers another node with a higher version.

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

  * `semaphores` is the amount of locks the server maintain, one per wallet.
    The number may be large (>100), if the node has processed a lot of wallets
    recently. If it's larger [than 1024](https://github.com/zold-io/zold/issues/199),
    it's a good reason to worry.

To be continued...

`date` is the current date and time on the server.

`hours_alive` is the time in hours your server is alive without a reboot.

## How to Contribute

It is a Ruby command line gem. First, install
[Ruby 2.3+](https://www.ruby-lang.org/en/documentation/installation/),
[Rubygems](https://rubygems.org/pages/download),
and
[Bundler](https://bundler.io/).
Then:

```bash
$ bundle update
$ rake
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
