# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'ipaddr'

# Host name or IP address of a node.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # A host name or an IP address, which may point back to the machine
  # it is resolved on; such a host means nothing when another node reports it.
  class Host
    def initialize(name)
      @name = name
    end

    def loopback?
      return true if @name.casecmp?('localhost')
      IPAddr.new(@name).loopback?
    rescue IPAddr::InvalidAddressError
      false
    end
  end
end
