require "agents"
require "yaml"

module GameEngine
  @@pref = nil
  
  def GameEngine.pref
    @@pref
  end
   
  def GameEngine.set_preference(yaml_file)
    @@pref = YAML.load(yaml_file)
    Agents.create(@@pref[:num],@@pref[:distance_type])
  end
  
  def GameEngine.main_loop
    t = Thread.new do 
      while true do
        # Figure out which agents are going to fight.
        a, b = Agents.choose(:use_relationship)
        # Retrieve output from each agent.
        a_choice = a.play(b.id)
        b_choice = b.play(a.id)
        # Calculate results.
        if a_choice >= b_choice then
          half = a_choice
        else
          half = b_choice
        end
        a_point = (b_choice/(a_choice+b_choice))*half*2
        b_point = (a_choice/(a_choice+b_choice))*half*2
        # Return results to agents.
        a.knotify_result(a_point,b.id,b_choice)
        b.knotify_result(b_point,a.id,a_choice)
        # Unlock current agents.
        Agents.unchoose(a.id,b.id)
      end
    end
    return t
  end
  
  def GameEngine.start_monitor(stat)
    return Agents.monitor(stat,@@pref[:regeneration_method])
  end
end
