<img src="http://www.zold.io/logo.svg" width="92px" height="92px"/>

This is how you install `zold` Ruby gem on different platform.

We are very interested in your contribution to this document.
If and when you experience any problems, make changes here via a pull request.

Basically, you need to
install [Ruby 2.3+](https://www.ruby-lang.org/en/documentation/installation/),
[Rubygems](https://rubygems.org/pages/download), and
then the [gem](https://rubygems.org/gems/zold).

We recommend to host nodes at
[AWS](https://aws.amazon.com/) or
[DigitalOcean](https://www.digitalocean.com/).

## Debian 9.4

```bash
$ sudo apt update -y
$ sudo apt install -y ruby-dev rubygems zlib1g-dev libssl-dev make build-essential
$ gem install --no-ri --no-rdoc zold
```

## Ubuntu 16.04

```bash
$ sudo apt-get update -y
$ sudo apt-get install -y ruby-dev rubygems zlib1g-dev libssl-dev build-essential
$ gem install --no-ri --no-rdoc zold
```

## OSX

With [Homebrew](https://brew.sh/) (recommended):

```bash
$ brew install rbenv ruby-build
$ rbenv install 2.5.1
$ rbenv global 2.5.1
$ ruby -v
$ gem install --no-ri --no-rdoc zold
```

Without homebrew:

... please contribute ...

## Windows

... please contribute ...

## CentOS 7.5

As a `root` user:

```bash
$ sudo yum install zlib-devel gcc gcc-c++ ruby-devel rubygems ruby
$ gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
$ curl -sSL https://get.rvm.io | bash -s stable
$ source /etc/profile.d/rvm.sh
$ rvm install 2.5.1
$ gem install --no-ri --no-rdoc zold
```

## Amazon Linux (AWS EC2 default image)

```
$ sudo yum install zlib-devel gcc gcc-c++ ruby-devel rubygems ruby
$ gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
$ curl -sSL https://get.rvm.io | bash -s stable
$ source $HOME/.rvm/scripts/rvm
$ rvm install 2.5.1
$ gem install --no-ri --no-rdoc zold
```
