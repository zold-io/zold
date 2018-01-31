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
  * There is no mining; the only way to get ZOLD is to earn it
  * The wallet no.0 belongs to the issuer and may have a negative balance
  * A wallet is an XML file
  * There is no central ledger, each wallet has its own personal ledger
  * The network of communicating nodes maintains wallets of users
  * Anyone can add a node to the network
  * A mediator, a node that processes a payment, gets 0.16% of it

## How to Use

Install [Rubygems](https://rubygems.org/pages/download) and then run:

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
  * `zold commit` creates and commits a new payment to the wallet
  * `zold push` pushes a wallet to the network

For more options just run:

```bash
$ zold --help
```

## Architecture

The list of a few backbone nodes is hard-coded in this Git repository.

Each node is an HTTP server with a RESTful API.

Each running node maintains some wallets; each wallet is an XML file, e.g.:

```xml
<wallet>
  <name>yegor256</name>
  <pkey><!-- public PGP key, 256 bytes --></pkey>
  <ledger>
    [...]
    <txn id="35">
      <date>2017-07-19T21:24:51.136Z</date>
      <beneficiary>jeff</beneficiary>
      <amount>-560</amount>
      <sign><!-- PGP signature of the payer --></sign>
    </txn>
  </ledger>
</wallet>
```

All amounts are signed 128-bit integers in 10<sup>-12</sup>, where 5ZLD=5,000,000,000,000.

The `<sign>` contains the following text block, signed by the payer:
`date`, `beneficiary`, and
64 bytes of [salt](https://en.wikipedia.org/wiki/Salt_%28cryptography%29).

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
it to other nodes and obtains their acknowledgments.

**Merge**.
If a node receives a wallet that contains transactions that are younger
than transactions in its local copy, a merge operation is
performed. If there are conflicts, like a negative balance, the node
deletes recent transactions from the wallet and from other affected wallets.

**Init**.
The client creates an empty wallet XML.

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

