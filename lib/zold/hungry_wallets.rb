# frozen_string_literal: true

require 'delegate'

module Zold
  # Wallets decorator that adds missing wallets to the queue to be pulled later.
  class HungryWallets < SimpleDelegator
    # @todo #280:30min Add to the queue. Once in there, try
    #  to pull it as soon as possible as is described in #280.
    def find(id)
      super(id)
    end
  end
end
