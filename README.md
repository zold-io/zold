<img src="http://www.zold.io/logo.svg" width="64px" height="64px"/>

[![Managed by Zerocracy](http://www.0crat.com/badge/C91QJT4CF.svg)](http://www.0crat.com/p/C91QJT4CF)
[![DevOps By Rultor.com](http://www.rultor.com/b/yegor256/Zold)](http://www.rultor.com/p/yegor256/Zold)
[![We recommend RubyMine](http://img.teamed.io/rubymine-recommend.svg)](https://www.jetbrains.com/ruby/)

[![Build Status](https://travis-ci.org/zerocracy/zold.svg)](https://travis-ci.org/zerocracy/zold)
[![Build status](https://ci.appveyor.com/api/projects/status/orvfo2qgmd1d7a2i?svg=true)](https://ci.appveyor.com/project/zerocracy/zold)
[![PDD status](http://www.0pdd.com/svg?name=zerocracy/zold)](http://www.0pdd.com/p?name=zerocracy/zold)
[![Gem Version](https://badge.fury.io/rb/zold.svg)](http://badge.fury.io/rb/zold)
[![Test Coverage](https://img.shields.io/codecov/c/github/zerocracy/zold.svg)](https://codecov.io/github/zerocracy/zold?branch=master)

[![Dependency Status](https://gemnasium.com/zerocracy/zold.svg)](https://gemnasium.com/zerocracy/zold)
[![Maintainability](https://api.codeclimate.com/v1/badges/7489c1d2bacde40ffc09/maintainability)](https://codeclimate.com/github/zerocracy/zold/maintainability)

**NOTICE**: It's an experiment and a very early draft! Please, feel free to
submit your ideas or pull requests.

ZOLD is a crypto currency.

ZOLD is going to solve these problems:

  * Blockchain is slow and [doesn't scale](https://en.wikipedia.org/wiki/Bitcoin_scalability_problem)
  * Crypto mining makes irrelevant strangers rich
  * High volatility makes cryptos suitable mostly for the black market

ZOLD is:

  * Fast
  * Scalable
  * Anonymous

ZOLD principles include:

  * The entire code base is open source
  * There is no mining; the only way to get ZOLD is to receive it from someone else
  * Only 2<sup>63</sup> numerals (no fractions) can technically be issued
  * The first wallet belongs to the issuer and may have a negative balance
  * A wallet is an XML file
  * There is no central ledger, each wallet has its own personal ledger
  * Each transaction in the ledger is confirmed by [RSA](https://simple.wikipedia.org/wiki/RSA_%28algorithm%29) encryption
  * The network of communicating nodes maintains wallets of users
  * Anyone can add a node to the network

## How to Use

Install Ruby 2.2+, [Rubygems](https://rubygems.org/pages/download), and then run:

```bash
$ gem install zold
```

Then, either run it as a node:

```bash
$ zold start
```

Or do one of the following:

  * `zold init` creates a new wallet (you have to provide PGP keys)
  * `zold pull` pulls a wallet from the network
  * `zold send` creates a new transaction
  * `zold push` pushes a wallet to the network

For more options and commands just run:

```bash
$ zold --help
```

## Glossary

A **node** is an HTTP server with a RESTful API, a maintainer of wallets.

A **client** is a command line Ruby gem [`zold`](https://rubygems.org/gems/zold).

A **wallet** is an XML file with a ledger of all transactions inside.

A **transaction** is a money transferring operation between two wallets.

## Data

A wallet may look like this:

```xml
<wallet>
  <id>123456</id>
  <pkey><!-- public RSA key, 256 bytes --></pkey>
  <ledger>
    [...]
    <txn id="35">
      <date>2017-07-19T21:24:51.136Z</date>
      <beneficiary>927284</beneficiary>
      <amount>-560</amount>
      <sign><!-- RSA signature of the payer --></sign>
    </txn>
  </ledger>
</wallet>
```

Wallet `<id>` is an unsigned 32-bit integer.

Transaction `id` is an unsigned 16-bit integer.

Transaction `date` is an unsigned 32-bit integer, meaning
milliseconds since
[epoch](https://en.wikipedia.org/wiki/Epoch_%28reference_date%29).

All amounts are signed 64-bit integers, where 1ZLD by convention equals to
2<sup>24</sup> (16,777,216). Thus, the technical capacity
of the currency is 549,755,813,888 (half a trillion).

The `<sign>` exists only in transactions with negative `amount`.
It contains an RSA signature of a data block, created by the wallet owner:
`date`, `amount`, `beneficiary` and
64 bytes of [salt](https://en.wikipedia.org/wiki/Salt_%28cryptography%29).

The list of a few backbone nodes is hard-coded in this Git repository.

## Architecture

**Pull**.
The client connects to a random closest node and pulls a wallet. If the node
doesn't have the wallet, it tries to find it in the network.
Then, it calculates and prints the balance to the user.

**Commit**.
The user provides the amount and the destination wallet name.
The client pulls the destination wallet and adds
a new XML element `<txn/>` to both wallets.

**Push**.
The client sends two wallets to a random closest node, which checks
the validity of the deduction and propagates
both wallets to _all_ other nodes in a [2PC](https://en.wikipedia.org/wiki/Two-phase_commit_protocol)
manner: acknowledgment first, commit next.
If a node receives a wallet that contains transactions that are younger
than transactions in its local copy, a merge operation is
performed. If the balance after the merge is negative, the push is rejected.

**Init**.
The client creates an empty wallet XML and assigns a random `id` for it.

**Start**.
The node manifests itself to one of the backbone nodes, which
propagates the manifestation to other nodes, they propagate further.
When any node goes down, the node that detected such a situation,
notifies other nodes and they exlude the failed node from the list.

## Corner Cases

**Too long wallet**.
If a wallet has too many transactions, its validation will take too long, since
will require many cross-wallet checks. How to solve this?

**DDoS**.
We may have too many simultaneous `push` operations to the network,
which may/will cause troubles. What to do?

## License (MIT)

Copyright (c) 2018 Zerocracy, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the 'Software'), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

