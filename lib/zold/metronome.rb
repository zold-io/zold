# Copyright (c) 2018 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require_relative 'log'
require_relative 'verbose_thread'

# Background routines.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Metronome
  class Metronome
    def initialize(log = Log::Quiet.new)
      @log = log
      @threads = []
    end

    def add(routine)
      @threads << Thread.start do
        VerboseThread.new(@log).run(true) do
          Thread.current.name = routine.class.name
          step = 0
          loop do
            start = Time.now
            routine.exec(step)
            sleep(1)
            step += 1
            @log.debug("Routine #{routine.class.name} ##{step} done in #{((Time.now - start) / 60).round(2)}s)")
          end
        end
      end
      @log.info("Added #{routine.class.name} to the metronome")
    end

    def stop
      @threads.each do |t|
        t.exit
        @log.debug("#{t.name} thread stopped")
      end
      @log.info("#{@threads.count} routine threads stopped")
    end
  end
end
