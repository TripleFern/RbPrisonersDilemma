require "game_engine"
require "agent_status"

module PDApplication

@@about_this_program = <<END_OF_STRING
Prisoners Dilemma   --- A Simulation.
 -- From a Buddhist perspective. --
(c) 2007-2008 Tatsushi Miyazaki (TripleFern)
END_OF_STRING
  
  @@game_threads = ThreadGroup.new
  @@stat = AgentStatus.new

  def PDApplication.start(game_preference,agent_preference)
    puts @@about_this_program
    game_pref_file = File.open(game_preference,"r")
    GameEngine.set_preference(game_pref_file)
    @@game_threads.add(GameEngine.main_loop())
    @@game_threads.add(GameEngine.start_monitor(@@stat))
    @@game_threads.list.each do |th|
      th.abort_on_exception = true
    end
  end
  
  def PDApplication.stop()
    threads_list = @@game_threads.list
    threads_list.each do |th|
      th.kill
    end
    threads_list.each do |th|
      th.join
    end
    puts "\nCalculation Finished."
  end
  
  def PDApplication.snooze()
    
  end
  
  def PDApplication.resume()
    
  end

end

PDApplication.start("preference.yaml","")

t = Thread.new{sleep 50}
t.join

PDApplication.stop()


