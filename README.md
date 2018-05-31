<img src="http://www.zold.io/logo.svg" width="92px" height="92px"/>

[![EO principles respected here](http://www.elegantobjects.org/badge.svg)](http://www.elegantobjects.org)
[![Managed by Zerocracy](https://www.0crat.com/badge/C91QJT4CF.svg)](https://www.0crat.com/p/C91QJT4CF)
[![DevOps By Rultor.com](http://www.rultor.com/b/yegor256/Zold)](http://www.rultor.com/p/yegor256/Zold)
[![We recommend RubyMine](http://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

[![Build Status](https://travis-ci.org/yegor256/zold.svg)](https://travis-ci.org/yegor256/zold)
[![Build status](https://ci.appveyor.com/api/projects/status/ypctxm5ohrtp2kr4?svg=true)](https://ci.appveyor.com/project/yegor256/zold)
[![PDD status](http://www.0pdd.com/svg?name=yegor256/zold)](http://www.0pdd.com/p?name=yegor256/zold)
[![Gem Version](https://badge.fury.io/rb/zold.svg)](http://badge.fury.io/rb/zold)
[![Test Coverage](https://img.shields.io/codecov/c/github/yegor256/zold.svg)](https://codecov.io/github/yegor256/zold?branch=master)

[![Dependency Status](https://gemnasium.com/yegor256/zold.svg)](https://gemnasium.com/yegor256/zold)
[![Maintainability](https://api.codeclimate.com/v1/badges/7489c1d2bacde40ffc09/maintainability)](https://codeclimate.com/github/yegor256/zold/maintainability)

**NOTICE**: It's an experiment and a very early draft! Please, feel free to
submit your ideas and/or pull requests.

Here is the [White Paper](https://github.com/yegor256/zold/raw/master/wp/wp.pdf).

The license is [MIT](https://github.com/yegor256/zold/blob/master/LICENSE.txt).

## How to Use

First, install [Ruby 2.3+](https://www.ruby-lang.org/en/documentation/installation/),
[Rubygems](https://rubygems.org/pages/download), and
the [gem](https://rubygems.org/gems/zold):

```bash
$ sudo apt-get install ruby-dev rubygems zlib1g-dev libssl-dev
$ gem install zold
```

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
In order to do that just run (with your own wallet ID, of course,
and your own public IP address instead of `4.4.4.4`):

```bash
$ zold node --trace --verbose --invoice=5f96e731e48ae21f --host=4.4.4.4
```

Then, open the page `4.4.4.4:4096` in your browser.
If you see a simple JSON document, everything is fine.
Next, hit <kbd>Ctrl</kbd>+<kbd>c</kbd> and run this line, in order
to start the node and make sure it will be online even when you log off
(replace `CMD` with the command you just executed before):

```bash
$ nohup bash -c 'while CMD; do gem install zold; done' &
```

Grateful users of the system will pay "taxes" to your wallet
for the maintenance of their wallets.

## Frequently Asked Questions

> Where are my PGP private/public keys?

They are are `~/.ssh/id_rsa` (private key) and `~/.ssh/id_rsa.pub` (public key).
Make sure you have a copy of your private key in some safe place.
If you lose the public key, it's not a problem, since your wallet has it.
But the private key is your personal asset.
Anyone can use your wallet if he/she has the private key.
Keep it safe and secure!

> What is the best way to check the balance of the rewards collected by nodes?

You just do `zold pull <Wallet_ID>` and the rewards (taxes) will be visible there.

> Can I setup multiple nodes with one wallet address?

Yes, you can run many nodes with the same wallet ID.

> Is there a way to increase the number of threads in order to maximize computing power of multiple core machines?

Yes, you can use `--threads` command line argument for your node
and the number of threads will be as big as you wish.

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

The build has to be clean. If it's not, [submit an issue](https://github.com/yegor256/zold/issues).

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
