require 'delegate'

module Zold
  # Wallets decorator that adds missing wallets to the queue to be pulled later.
  class HungryWallets < SimpleDelegator
    # @todo #280:30min Add to the queue and return nil.
    #  Then try to pull it as soon as possible as described in #280.
    def find(id)
      super(id)
    end
  end
end
