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

1 ZLD by convention equals to 2<sup>24</sup> (16,777,216) _zents_.
Thus, the technical capacity of the currency is 549,755,813,888 ZLD (half a trillion).

## How to Use

Install Ruby 2.2+, [Rubygems](https://rubygems.org/pages/download), and then run:

```bash
$ sudo apt-get install ruby-dev rubygems zlib1g-dev
$ gem install zold
```

Then, either run it as a node:

```bash
$ zold start
```

Or do one of the following:

  * `zold remote` manipulates the list off remote nodes;
  * `zold create` creates a new wallet (you have to provide PGP keys);
  * `zold fetch` downloads all copies of the wallet from the network;
  * `zold merge` merges all copies of the wallet into the local one;
  * `zold pull` first `fetch`, then `merge`;
  * `zold show` prints out all known details of a wallet (incl. its balance);
  * `zold pay` creates a new transaction;
  * `zold push` pushes a wallet to the network.

For more options and commands just run:

```bash
$ zold --help
```

You will need PGP keys in `~/.ssh`. To generate them, if you don't have them
yet, you can run:



## Glossary

**Node** is an HTTP server with a RESTful API, a maintainer of wallets
and a command line Ruby gem [`zold`](https://rubygems.org/gems/zold).

**Network** is a set of all nodes available online.

**Score** is the amount of "hash sufficies" a node has at any given moment of time.

**Wallet** is a text file with a ledger of all transactions inside.

**Transaction** is a money transferring operation between two wallets.

**MSS** (minimum summary score) is a summary of all scores required to trust a wallet.

## Score

Each node calculates its own score. First, it takes the current timestamp
in UTC [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601),
for example `2017-07-19T21:24:51Z ` (with a trailing space). Then, it appends
its own host name or IP address to it, space, TCP port number, and a space.
Then, it attempts to append any
arbitrary text (has to match `[a-zA-Z0-9]+`) to the end of it and to calculate SHA-256 of the text
in the hexadecimal format, for example:

```
Input: "2017-07-19T21:24:51Z b1.zold.io 4096 the-suffix"
SHA-256: "eba36e52e1ee674d198f486e07c8496853ffc8879e7fe25329523177646a96a0"
```

The node attempts to try different sufficies until one of them produces
SHA-256 hash that ends with `00000000` (eight zeros). For example, this
suffix `11edb424c` works (it took 212 minutes to find it on 2.3GHz Intel Core i7):

```
Input: "2017-07-19T21:24:51Z b1.zold.io 4096 11edb424c"
SHA-256: "34f48e0eee1ed12ad74cb39418f2f6e7442a776a7b6182697957650e00000000"
```

When the first suffix is found, the score of the node is 1. Then, to
increase the score by one, the node has to find the next suffix, which
can be added to the first 20 characters of the previous hash
in order to obtain a new hash with trailing zeros, for example:

```
Input: "34f48e0eee1ed12ad74c "
SHA-256: "..."
```

And so on.

The score is valid only when the starting time point is earlier than
current time, but not earlier than 24 hours ago.

## Operations

### Remote

Each node maintains a list of visible "remote" nodes.
The gem is shipped together with a hard-coded list of a few of them.

  * `remote update` goes through the list of all remote nodes,
    checks their availability, and either removes them from the list or
    adds new nodes to the list.

  * `remote add <IP>` adds a new remote node to the list.

  * `remote remove <IP>` removes a remote node.

  * `remote show` prints the entire list of remote nodes.

The node always tries to make sure the summary of all scores in the
list of remote nodes is right above the MSS, but not more.

### Fetch

The node attempts to pull the wallet from the first remote.
The remote returns the wallet, if it exists. Otherwise, rejects the request
and returns the list of all remotes known to it.

The node stores the content of the wallet and the score of the remote
to the local storage.
The local storage doesn't keep all remote copies, but only their unique
versions and summary scores for each version.

Fetching stops when:

  * Total score is above MSS _or_
  * There is only one version and the total score is above ½ MSS.

If not, the node attempts the next remote in the list.

### Merge

The remote copy is accepted "as is" without verifications if:

  * All remote copies are identical _and_
  * Their summary score is above the MSS.

Otherwise, the node goes through the entire list of transactions visible in all
remote copies and merges them one by one into the "head" copy.
The decision is made per each transaction.

If a transaction exists in the head, it remains there.

Otherwise, if it's a positive transaction that increases the balance of the head copy,
the signature is validated (in the paying wallet, which is pulled first)
and it goes into the head. The transaction gets a new ID.

If it's a negative transaction, the decision is made between all copies.
The one with the largest score goes first, if the balance of the wallet
is big enough. Then, the next one in the line and so on. The transactions
that negate the balance are rejected.

### Pay

The node pulls both wallets. Then, say, the user makes a payment
from the wallet `0123456789abcdef` to the wallet `4567456745674567`:

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

### Push

The node sends a package of a few wallets to the biggest remote available
(with the highest score).
The package must also include a fee to the wallet that belongs to the
remote.

The remote stores them as remote copies and performs _pull_.

The remote sends "pull requests" to all available nodes.
They must pull from the node for free, if their scores are lower or equal
to the score of the node.

## RESTful API

The full list of RESTful resources:

  * `/` (GET): status page of the node, in JSON

  * `/remotes` (GET): load all known remotes in JSON

  * `/wallet/<ID>` (GET): fetch wallet in JSON

  * `/wallet/<ID>` (PUT): push wallet

Each HTTP response contains `Content-type` header.

## Files

Each wallet is a text file with the name equal to the wallet ID, for example:

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
  * Amount (integer);
  * Wallet ID of the beneficiary;
  * Details: `/[a-zA-Z0-9 -.]{1,128}/`;
  * RSA signature of the sender of "ID;amount;beneficiary;details" text.

Transactions with positive amount don't
have RSA signatures. Their IDs point to ID fields of corresponding
beneficiaries' wallets.

The combination "ID+Beneficiary" is unique in the entire wallet.

The directory `.zold` is automatically created and contains system data.

`.zold/remotes` is a comma-separated file with a list of remote nodes with
these columns:

  * Address or IP;
  * TCP port (usually 4096);
  * Score (positive integer);
  * Time of score update, ISO 8601.

`.zold/copies` is a directory of directories, named after wallet IDs,
each of which contains copies of wallets, named like `1`, `2`, `3`, etc. Also,
each sub-directory contains a comma-separated file `scores` with these columns:

  * The name of the copy, e.g. `1`;
  * The address of the remote (host name or IP);
  * The TCP port number of the remote;
  * The score (positive integer);
  * The time of fetching, in ISO 8601.

