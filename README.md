**NOTICE**: It's a very early draft!

ZOLD is a crypto currency.

ZOLD is going to solve these problems:

  * Blockchain is slow and doesn't scale
  * Mining makes strangers rich
  * High volatility makes crypto dark

The principles behind ZOLD:

  * There is only one issuer: [Zerocracy, Inc.](http://www.zerocracy.com)
  * The only way to get ZOLD is to earn it
  * [Zerocracy](http://www.zerocracy.com) guarantees to buy back for $1/ZOLD
  * No history of transactions
  * Consistency is guaranteed by protocols, not data
  * The entire code base is open source
  * Each transaction must be approved by its sender and receiver

## How to Use

Install [Rubygems](https://rubygems.org/pages/download) and then run:

```bash
gem install zold
```

Then, either run it as a node:

```bash
zold run
```

Or do one of the following:

  * `zold create` creates a new wallet (you have to provide PGP keys)
  * `zold pay` sends a payment
  * `zold check` checks the balance of a wallet

For more options just run:

```bash
zold --help
```

## Architecture

Each running node contains a list of wallets; each wallet contains:

  * ID: unsigned 64-bit integer
  * Public PGP key of the owner: 256 bytes (2048 bits)
  * Balance: signed 128-bit integer
  * Version: unsigned 64-bit integer

The wallet with the largest `version` number contains the current balance.

There is a [3PC](https://en.wikipedia.org/wiki/Three-phase_commit_protocol) protocol:

  1. A node locks a place in a distributed payment queue.

  2. The node confirms the payment.

  3. Other nodes modify balances of sender's and recepient's wallets.

**Phase I**.
Each node maintains a payment queue, where each payment includes:

  * Payment ID: unsigned 32-bit integer
  * Sender wallet ID and version
  * Recepient wallet ID and version
  * Amount
  * PGP sign of the sender
  * List of friend IPs and their payment IDs in their queues

When a lock request arrives, the node asks its best "friends" (other nodes) to
lock a place in their queues and then compares their responses. If the versions
they managed to lock are not exactly the same, it asks them
to try to lock again. The process repeats, until all friends' replies are similar.

**Phase II**.
The node sends a confirmation request to its friends, which includes
the payment ID.

**Phase III**.
Each node modifies the balances in its local list of wallets and responds
with a payment confirmation status. The payment gets removed from the queue.

## Consistency and Security

The list of friends is hard-coded in the software. It includes only the
nodes that are trusted by the creators of this software. The list may be
extended in runtime, using the statistics of the most actively contributing
nodes.

If, at Phase I, some node doesn't synchronize its responses with other
nodes in more than eight attempts, it is excluded from the list of friends
for some period of time (quarantine).

To avoid long-lasting locks of the queue, a payment is removed from the
queue if it stays there for longer than 60 seconds.

A DoS attack to the distribution payment queue is a potential threat.

