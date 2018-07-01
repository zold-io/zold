module Zold
  # Wallets decorator that adds missing wallets to the queue to be pulled later.
  class HungryWallets
    def initialize(wallets)
      @wallets = wallets
    end

    # @todo #280:30min Add to the queue and return nil.
    #  Then try to pull it as soon as possible as described in #280.
    def find(id)
      @wallets.find(id)
    end

    private

    def method_missing(method_name, *args, &block)
      if @wallets.respond_to?(method_name)
        @wallets.send(method_name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @wallets.respond_to?(method_name) || super
    end
  end
end
