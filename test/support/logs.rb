module Logs
  def log
    # $log = Zold::Log::Quiet.new
    @log ||= Zold::Log::Verbose.new
  end
end
