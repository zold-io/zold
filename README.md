<img src="http://www.zold.io/logo.svg" width="64px" height="64px"/>

[![Managed by Zerocracy](https://www.0crat.com/badge/C91QJT4CF.svg)](http://www.0crat.com/p/C91QJT4CF)
[![DevOps By Rultor.com](http://www.rultor.com/b/yegor256/Zold)](http://www.rultor.com/p/yegor256/Zold)
[![We recommend RubyMine](http://img.teamed.io/rubymine-recommend.svg)](https://www.jetbrains.com/ruby/)

[![Build Status](https://travis-ci.org/zerocracy/zold.svg)](https://travis-ci.org/zerocracy/zold)
[![Build status](https://ci.appveyor.com/api/projects/status/ypctxm5ohrtp2kr4?svg=true)](https://ci.appveyor.com/project/yegor256/zold)
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
  * A wallet is an plain text file
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
  * `zold balance` checks the balance of a wallet
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

A **cluster** is a list of 16 nodes that maintain a copy of wallet.

## Data

A wallet may look like this:

```text
12345678abcdef
AAAAB3NzaC1yc2EAAAADAQABAAABAQCuLuVr4Tl2sXoN5Zb7b6SKMPrVjLxb...

34;2017-07-19T21:24:51Z;-560700;98bb82c81735c4ee;for services;SKMPrVjLxbM5oDm0IhniQQy3shF...
35;2017-07-19T21:25:07Z;-56990;98bb82c81735c4ee;;QCuLuVr4Tl2sXoN5Zb7b6SKMPrVjLxb...
134;2017-07-19T21:29:11Z;647388;18bb82dd1735b6e9;;
36;2017-07-19T22:18:43Z;-884733;38ab8fc8e735c4fc;for fun;2sXoN5Zb7b6SKMPrVjLxb7b6SKMPrVjLx...
```

Lines are separated by either CR or CRLF, doesn't matter. There is a
header and a ledger, separated by an empty line.
The header includes two lines:

  * Wallet ID, a 64-bit unsigned integer
  * Public RSA key of the wallet owner

The ledger includes transactions, one per line. Each transaction line
contains fields separated by a semi-colon:

  * Transaction ID, an unsigned 16-bit integer
  * Date and time, in [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601)
  * Amount
  * Wallet ID of the beneficiary
  * Details: `/[a-zA-Z0-9 -.]{0,128}/`
  * RSA signature of "ID;amount;beneficiary;details" text

Transactions with positive amount don't
have RSA signatures. Their IDs point to ID fields of corresponding
beneficiaries' wallets.

1 ZLD by convention equals to 2<sup>24</sup> (16,777,216).
Thus, the technical capacity of the currency is
549,755,813,888 ZLD (half a trillion).

## Architecture

**Pull**:

  * The client retrieves the list of cluster nodes.
  * The client sends `GET` request to all nodes.
  * The client compares received files and picks the most popular one.

**Push**:

  * The user modifies its local version of the wallet file.
  * The client retrieves the list of cluster nodes.
  * The client sends `LOCK` request to all 16 nodes of the cluster.
  * They check the "diff" of the wallet and reply with `ACK` response.
  * The client sends `COMMIT` request to all 16 nodes.
  * They switch to the new version of the wallet and reply with `DONE` response.

**Rotate**:

  * At any time any node can send `POLL` request to all cluster nodes.
  * The request may suggest to either invite a new node to a cluster or reject an existing one.
  * Each node in the cluster votes and returns `VOTE` response.
  * If the summary vote is positive, the node sends `ROTATE` request to all cluster nodes.
  * All cluster nodes update their lists of cluster members.

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

