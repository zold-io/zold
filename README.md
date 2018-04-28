<img src="http://www.zold.io/logo.svg" width="64px" height="64px"/>

[![EO principles respected here](http://www.elegantobjects.org/badge.svg)](http://www.elegantobjects.org)
[![Managed by Zerocracy](https://www.0crat.com/badge/C91QJT4CF.svg)](https://www.0crat.com/p/C91QJT4CF)
[![DevOps By Rultor.com](http://www.rultor.com/b/yegor256/Zold)](http://www.rultor.com/p/yegor256/Zold)
[![We recommend RubyMine](http://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

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

ZOLD principles include:

  * The entire code base is open source;
  * There is no mining, the only way to get ZOLD is to receive it from someone else;
  * Only 2<sup>63</sup> numerals (no fractions) can technically be issued;
  * The first wallet belongs to the issuer and may have a negative balance;
  * A wallet is a plain text file;
  * There is no central ledger, each wallet has its own personal ledger;
  * Each transaction in the ledger is confirmed by [RSA](https://simple.wikipedia.org/wiki/RSA_%28algorithm%29) encryption;
  * The network of communicating nodes maintains wallets of users;
  * Anyone can add a node to the network.

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

  * `zold init` creates a new wallet (you have to provide PGP keys);
  * `zold pull` pulls a wallet from a random node;
  * `zold show` prints out all known details of a wallet (incl. its balance);
  * `zold send` creates a new transaction;
  * `zold push` pushes a wallet to all known nodes.

For more options and commands just run:

```bash
$ zold --help
```

## Glossary

A **node** is an HTTP server with a RESTful API, a maintainer of wallets
and a command line Ruby gem [`zold`](https://rubygems.org/gems/zold).

A **score** is the amount of hash prefixes a node has at any given moment of time.

A **wallet** is a text file with a ledger of all transactions inside.

A **transaction** is a money transferring operation between two wallets.

## Score

Each node calculates its own score. First, it takes the current timestamp
in UTC [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601),
for example `2017-07-19T21:24:51Z`. Then, it attempts to append any
arbitrary text to the end of it and to calculate SHA-256 in the hexadecimal format,
for example:

```
Input: "2017-07-19T21:24:51Z the suffix"
SHA-256: "eba36e52e1ee674d198f486e07c8496853ffc8879e7fe25329523177646a96a0"
```

The node attempts to try different sufficies until one of them produces
SHA-256 hash that ends with `00000000` (eight zeros). For example, this
suffix may work:

```
Input: "2017-07-19T21:24:51Z "
SHA-256: "eba36e52e1ee674d198f486e07c8496853ffc8879e7fe25329523177646a96a0"
```

When the first suffix is found, the score of the node is 1. Then, to
increase the score by one, the node has to find the next suffix, which
can be added to the hash in order to obtain a new hash with trailing zeros,
for example:

```
Input: "eba36e52e1ee674d198f486e07c8496853ffc8879e7fe25329523177646a96a0 "
SHA-256: "eba36e52e1ee674d198f486e07c8496853ffc8879e7fe25329523177646a96a0"
```

And so on.

The score is valid only when the starting time point is earlier than
current time, but not earlier than 24 hours ago.

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

  * Wallet ID, a 64-bit unsigned integer;
  * Public RSA key of the wallet owner.

The ledger includes transactions, one per line. Each transaction line
contains fields separated by a semi-colon:

  * Transaction ID, an unsigned 16-bit integer;
  * Date and time, in [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601);
  * Amount;
  * Wallet ID of the beneficiary;
  * Details: `/[a-zA-Z0-9 -.]{1,128}/`;
  * RSA signature of the sender of "ID;amount;beneficiary;details" text.

Transactions with positive amount don't
have RSA signatures. Their IDs point to ID fields of corresponding
beneficiaries' wallets.

1 ZLD by convention equals to 2<sup>24</sup> (16,777,216) __zents__.
Thus, the technical capacity of the currency is
549,755,813,888 ZLD (half a trillion).

## End-to-end positive use case

Let's say a user has a wallet on his laptop and its ID is `0123456789abcdef`.

The user pulls the receiving wallet:

```bash
zold pull 4567456745674567
```

The client downloads the public list of root nodes.
The client downloads lists of top-score nodes from each root node, and
sorts all nodes by their scores ("uplinks").
The client attempts to pull the wallet `4567456745674567` from the first
randomly selected uplink. If the wallet is there, it is delivered together
with the score of the node. The client validates the score and goes
to the next node. The client considers the wallet valid when the summary
score is over _X_.

Then, the user makes a new transaction,
sending 5 ZLD to the receiving wallet:

```bash
zold send 0123456789abcdef 4567456745674567 5
```

The content of both files get changed. An outgoing transaction with a negative
amount gets added to the end of the paying wallet `0123456789abcdef`:

```text
500;2017-07-19T22:18:43Z;-83886080;4567456745674567;-;b6SKMPrVjLx...
```

The incoming transaction gets appended to the end of the receiving wallet
`4567456745674567`:

```text
500;2017-07-19T22:18:43Z;83886080;0123456789abcdef;-
```

The user pushes both wallets:

```
zold push
```

The client picks a random uplink and sends both wallets to it. The uplink
responds with a confirmation. The client picks the next random node and sends
both wallets to it too. The client goes from node to node until the
summary score is above _X_.

A node, when its score is changed, announces itself to all root nodes and
other nodes known to them.
