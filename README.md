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
  * There is only one issuer: [Zerocracy, Inc.](http://www.zerocracy.com)
  * There is no mining; the only way to get ZOLD is to receive it from someone else
  * Only 2<sup>63</sup> numerals (no fractions) can technically be issued
  * The wallet no.0 belongs to the issuer and may have a negative balance
  * A wallet is an XML file
  * There is no central ledger, each wallet has its own personal ledger
  * The network of communicating nodes maintains wallets of users
  * Anyone can add a node to the network
  * A mediator, a node that processes a transaction, gets 2<sup>-16</sup> (0.001525878%) of it

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
  * `zold commit` creates and commits a new transaction to the wallet
  * `zold push` pushes a wallet to the network

For more options just run:

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
  <pkey><!-- public PGP key, 256 bytes --></pkey>
  <ledger>
    [...]
    <txn id="35">
      <date>2017-07-19T21:24:51.136Z</date>
      <beneficiary>927284</beneficiary>
      <amount>-560</amount>
      <hash><!-- PGP signature of the payer --></hash>
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

The `<hash>` contains an [MD5](https://en.wikipedia.org/wiki/MD5) 16-bytes
hash of the following text block, signed by the payer:
`date`, `amount`, `beneficiary`, and
64 bytes of [salt](https://en.wikipedia.org/wiki/Salt_%28cryptography%29).
Thus, each transaction takes exactly 34 bytes.

The list of a few backbone nodes is hard-coded in this Git repository.

## Architecture

**Pull**.
The client connects to a random closest node and pulls a wallet. If the node
doesn't have the wallet, it tries to find it in the network. Then, the
client pulls all other wallets referenced in the main one, and validates
their signatures. Then, it prints the balance to the user.

**Commit**.
The user provides the amount and the destination wallet name. The client
pulls the destination wallet and adds a new XML element `<txn>` to both of them
together with the PGP signature received from the user.

**Push**.
The client sends the wallet to a random closest node. The node propagates
it to other nodes in a [2PC](https://en.wikipedia.org/wiki/Two-phase_commit_protocol)
manner: acknowledgment first, commit next.
If a node receives a wallet that contains transactions that are younger
than transactions in its local copy, a merge operation is
performed. If the balance after the merge is negative, the push is rejected.

**Init**.
The client creates an empty wallet XML and asks one of the backbone
nodes to generate a new `id` for it.

**Start**.
The node manifests itself to one of the backbone nodes, which
propagates the manifestation to other nodes, they propagate further.
When any node goes down, the node that detected such a situation,
notifies other nodes and they exlude the failed node from the list.

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

