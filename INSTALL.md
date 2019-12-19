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

It is recommended to have at least 2 CPUs and 2 Gb RAM.

## Debian 9.4

As a `root` user:

```bash
$ sudo apt update -y
$ sudo apt install -y ruby-dev rubygems zlib1g-dev libssl-dev make build-essential libcurl4-openssl-dev
$ gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
$ curl -sSL https://get.rvm.io | bash -s stable
$ source /etc/profile.d/rvm.sh
$ rvm install --default 2.5.1
$ gem install --no-ri --no-rdoc zold
```

## Ubuntu 16.04

As a `root` user:

```bash
$ sudo apt-get update -y
$ sudo apt-get install -y curl ruby-dev rubygems zlib1g-dev libssl-dev build-essential libcurl4-openssl-dev
$ gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
$ curl -sSL https://get.rvm.io | bash -s stable
$ source /etc/profile.d/rvm.sh
$ rvm install --default 2.5.1
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

Download and install [RubyInstaller (with Devkit)](https://rubyinstaller.org/downloads/).
If Windows Defender (or antivirus software) throws an error, ignore it and allow the file.
This file is known to trigger [false positives](https://groups.google.com/forum/#!topic/rubyinstaller/LCR-CbBoGOI).
Download and install [RubyGems](https://rubygems.org/pages/download). Manual install `ruby setup.rb` works.

Install [Zold gem](https://rubygems.org/gems/zold):

```
gem install zold
```

## CentOS 7.5

As a `root` user:

```bash
$ sudo yum install zlib-devel gcc gcc-c++ ruby-devel rubygems ruby curl-devel
$ gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
$ curl -sSL https://get.rvm.io | bash -s stable
$ source /etc/profile.d/rvm.sh
$ rvm install --default 2.5.1
$ gem install --no-ri --no-rdoc zold
```

## Amazon Linux (AWS EC2 default image)

```
$ sudo yum install zlib-devel gcc gcc-c++ ruby-devel rubygems ruby libcurl4-openssl-dev
$ gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
$ curl -sSL https://get.rvm.io | bash -s stable
$ source $HOME/.rvm/scripts/rvm
$ rvm install --default 2.5.1
$ gem install --no-ri --no-rdoc zold
```

## PFSense Firewall Configuration
If your node is behind a pfsense firewall, you will need to make some special configurations in order to allow traffic to properly reach your node.
```
1) Open the PFSense Web GUI Administration console and navigate to Firewall > NAT > Port Forward, followed by clicking "Add"
2) Configure the NAT rules with the following:
    > Interface: WAN
    > Protocol: TCP
    > Source Port: defaults
    > Destination Port: 4096
    > Redirect Target IP: the interface on which your node is listening for requests
    > Redirect Target Port: 4096
    > Description: Port Forwarding Rule for ZOLD
    > Filter rule association: pass
3) Verify configuration using either of these two methods. If you see a JSON document you have properly setup your node:
    > CLI: curl <ip>:4096
    > Browser: http://<ip>:4096
```

## Run in Kubernetes cluster
```yaml
apiVersion: v1
kind: Service
metadata:
  name: zold-node
spec:
  ports:
    - port: 80
      targetPort: 4096
  selector:
    app: zold-node
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zold-node
spec:
  selector:
    matchLabels:
      app: zold-node
  replicas: 1
  template:
    metadata:
      labels:
        app: zold-node
    spec:
      containers:
        - name: zold-node
          image: yegor256/zold
          command:
            - "/node.sh"
          args:
            # replace example.com with your domain
            - "--host=example.com"
            # replace invoice with your wallet id
            - "--invoice=invoice"
            - "--port=80"
          ports:
            - containerPort: 4096
---
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: zold-ingress
spec:
  rules:
      # replace with your domain
    - host: example.com
      http:
        paths:
          - backend:
              serviceName: zold-node
              servicePort: 80
```
