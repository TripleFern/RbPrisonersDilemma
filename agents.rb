require "monitor"
require "relationship_matrix"
require "logger"

class Agents
  
  @@agent_list = Array.new
  # id2off[id] returns current position in the relationship matrix.
  @@id2off = Hash.new  
  @@relationship_matrix = RelationshipMatrix.new
  @@distance_type = :rand
  @@current_point_weight = 0.25
  @@id_i  = 0
  @@id_j = 1
  @@doff = 2
  @@famoff = 3
  @@stoff = 4
  @@hum_net = 5
  @@sup_id = 0
  @@size = 0
  @@lock_list = Array.new
  @@lock_list.extend(MonitorMixin)
  @@lock_list_cond_to_mon = @@lock_list.new_cond
  @@lock_list_cond_revert = @@lock_list.new_cond
  @@force_monitor = false
  @@total_count = 0
  @@cut_off = 0.1
  @@low_threshold = 0.2
  @@upp_threshold = 0.8 #Maximum happiness:2.0.
  @@regeneration_methods = Hash.new
  # Returns the number of agents purged/reproduced.
  @@regeneration_methods[:simple] = lambda {|ordered| return 0,0}
  @@regeneration_methods[:stable] = lambda {|ordered|
    n = (@@size*@@cut_off).round
    Agents.purge(n)
    Agents.reproduce(n)
    return n,n
  }
  @@regeneration_methods[:fixed] = lambda {|ordered|
    low_cut = Agents.fetch_low_bound(ordered,0)
    upp_cut = Agents.fetch_upp_bound(ordered,0)
    Agents.purge(low_cut)
    Agents.reproduce(upp_cut)
    return low_cut, upp_cut
  }
  
  def Agents.binary_search(ordered,thres,shift,&block)
    if ordered.size == 1 then
      return shift+1 if yield(ordered[0],thres)
      return shift
    end
    tip = (ordered.size+1)/2
    if yield(ordered[tip-1],thres) then
      Agents.binary_search(ordered[tip..-1],thres,shift+tip,&block)
    else
      Agents.binary_search(ordered[0..(tip-1)],thres,shift,&block)
    end
  end
  
  def Agents.fetch_low_bound(ordered,shift)
    Agents.binary_search(ordered,@@low_threshold,shift){|item,thres| item.happiness <= thres}
  end
  
  def Agents.fetch_upp_bound(ordered,unshift)
    reverted = ordered.reverse
    Agents.binary_search(reverted,@@upp_threshold,unshift){|item,thres| item.happiness >= thres}
  end
    
  def regenerate(parent_num)
    return parent_num+(parent_num*(1.0-parent_num)*(rand(0)-0.5))
  end

  attr_accessor :id, :default_opponent_strategy, :weight, :div, :strategy, :happiness, :count, :genotype
  attr_accessor :listen, :listen_weight, :replier,:parent_id
      
  def initialize (id,parent=nil)
    if parent == nil then
      @parent_id = nil
      @id = id
      @genotype = [id]
      @default_opponent_strategy = rand(0)
      @weight = rand(0)
      @div = rand(3)+2
      @happiness = 0.5
      @count = 0
      @strategy = Array.new
      (1..@div).each {@strategy << rand(0)}
      @listen = rand(0)
      @listen_weight = rand(0)
      @replier = nil
      @source = nil
    else
      @parent_id = parent.id
      @id = id
      @genotype = parent.genotype + [id]
      @default_opponent_strategy = regenerate(parent.default_opponent_strategy)
      @weight = regenerate(parent.weight)
      @div = parent.div
      @happiness = parent.happiness
      @count = 0
      @strategy = parent.strategy.map{|i| regenerate(i)}
      @listen = regenerate(parent.listen)
      @listen_weight = regenerate(parent.listen_weight)
      @replier = nil
      @source = nil
    end
  end
  
  def ask_others(opponent_id)
    friends = @@relationship_matrix[@@id2off[@id]].sort {|i,j| i[@@famoff]<=>j[@@famoff]}
    friends.shift #-- Remove distance 0 .. which is the one itself.
    reply = nil
    m = nil
    (1..@@hum_net).each do 
      m = friends.shift
      reply = @@relationship_matrix[@@id2off[m[@@id_j]]][@@id2off[opponent_id]][@@stoff]
      break if reply != nil
    end
    if reply == nil then @replier = nil
    else  @replier = m[@@id_j]
    end
    return reply
  end
  
  def think (anticipation)
    i = (anticipation*@div).floor
    i = @div-1 if i == @div
    if strategy[i] == nil then
      dinfo = (@source.map{|j|j.to_s}).join(" ")
      raise "\nThinking error at strategy[#{i}] when @div = #{@div} where @source: #{dinfo}, @default: #{@default_opponent_strategy} and anticipation: #{anticipation}" 
    end
    return @strategy[i]
  end
  
  def play (opponent_id)
    #'strategy' is implemented as 0.0 being betrayal and 1.0 being cooperation.
    opponent_strategy = @@relationship_matrix[@@id2off[@id]][@@id2off[opponent_id]][@@stoff]
    @source = [:original, opponent_strategy]
    if opponent_strategy == nil then
      opponent_strategy = ask_others(opponent_id)
      if opponent_strategy == nil then
        opponent_strategy = @default_opponent_strategy
        @source = [:default, opponent_strategy]
      else
        @source = [:others,opponent_strategy]
      end
    elsif rand(0) > @listen then
      suggestion = ask_others(opponent_id)
      if suggestion != nil then
        opponent_strategy = (@listen_weight*suggestion)+((1.0-@listen_weight)*opponent_strategy)
        @source = [:others_rand,opponent_strategy]
      end 
    end
    current_strategy = think((@weight*opponent_strategy)+((1.0-@weight)*@default_opponent_strategy))
    return current_strategy
  end
  
  def knotify_result(point, opponent_id, current_opponent_strategy)
    @count += 1.0
    opponent_strategy = @@relationship_matrix[@@id2off[@id]][@@id2off[opponent_id]][@@stoff]
    if opponent_strategy == nil then
      @@relationship_matrix[@@id2off[@id]][@@id2off[opponent_id]][@@stoff] = current_opponent_strategy
    else
      @@relationship_matrix[@@id2off[@id]][@@id2off[opponent_id]][@@stoff] = 
        (current_opponent_strategy/@count)+(opponent_strategy*(@count-1.0)/@count)
    end
    if @replier != nil then
      if point > @happiness then
        @@relationship_matrix[@@id2off[@id]][@@id2off[@replier]][@@famoff] =
          @@relationship_matrix[@@id2off[@id]][@@id2off[@replier]][@@famoff]/2.0
      end
      @replier = nil
    end
    @happiness = (@@current_point_weight*point) + ((1-@@current_point_weight)*@happiness)
    emotion = Math.sqrt(Math.sqrt(point/2.0))
    num = emotion*(@happiness/2.0)*@default_opponent_strategy + (1.0-emotion)*(1.0-(@happiness/2.0))*current_opponent_strategy
    den = emotion*(@happiness/2.0) + (1.0-emotion)*(1.0-(@happiness/2.0))
    @default_opponent_strategy = num/den
    raise "@default_opponent_strategy: out of range." if @default_opponent_strategy > 1 || @default_opponent_strategy < 0
  end
  
  def initialize_copy
    
  end
  
  def Agents.distance_type
    @@distance_type
  end
  
  def Agents.size
    @@size
  end
  
  def Agents.distance_type=(val)
    @@distance_type=val
  end
  
  def Agents.climate_shift
    
  end
  
  def Agents.purge(n)
    purge_list = @@agent_list.slice!(0,n)
    x_list = Array.new
    purge_list.each do |agent|
      x_list << @@id2off[agent.id]
    end
    @@size -= n
    @@relationship_matrix.remove(x_list,@@id2off)
  end
  
  def Agents.reproduce(n,is_first_run=false)
    children = Array.new
    (1..n).each do |i|
      children << Agents.new(@@sup_id,@@agent_list[i*(-1)])
      @@id2off[@@sup_id] = @@size
      @@sup_id += 1
      @@size += 1
    end
    @@agent_list.concat(children)
    raise "Distance type not specified!" if @@distance_type == nil
    if is_first_run then heredity = nil
    else heredity = children.map{|child| [child.id,@@id2off[child.parent_id]]}
    end
    @@hum_net = Math.log(@@agent_list.size).round
    @@relationship_matrix.repopulate(n,@@distance_type,heredity)
  end
  
  def Agents.monitor(agent_status, way_of_life)
    t = Thread.new do
      loop do 
        sleep 5
        @@lock_list.mon_enter
        @@force_monitor = true
        @@lock_list_cond_to_mon.wait_until { @@lock_list.empty? }
        @@agent_list.sort! {|i,j| i.happiness <=> j.happiness}
        agents_overview = @@agent_list.map {|i| [i.id, i.default_opponent_strategy, i.happiness, i.weight, i.div, i.count, i.genotype, i.listen, i.listen_weight]}
        agent_status.update(agents_overview, @@total_count)
        @@regeneration_methods[way_of_life].call(@@agent_list)
        @@force_monitor = false
        @@lock_list_cond_revert.broadcast
        @@lock_list.mon_exit
      end
    end
    return t
  end
  
  def Agents.create(num,distance_type)
    Agents.distance_type=distance_type
    Agents.reproduce(num,true)
  end
  
  def Agents.choose(scheme=:rand_every_time)
    @@lock_list.synchronize do
      if @@force_monitor == true then
        @@lock_list_cond_to_mon.signal
        @@lock_list_cond_revert.wait(nil)
      end 
      case scheme
      when :rand_every_time
        lst = Array.new(2) do |i|
          r = rand(@@size)
          redo if @@lock_list.include? @@agent_list[r].id
          @@lock_list << @@agent_list[r].id
          next @@agent_list[r]
        end
      when :use_relationship
        lst = Array.new(1) do |i|
          r = rand(@@size)
          redo if @@lock_list.include? @@agent_list[r].id
          @@lock_list << @@agent_list[r].id
          next @@agent_list[r]
        end
        lnd = Array.new(1) do |u|
          total_prob = 0
          prob_list = @@relationship_matrix.kinship[@@id2off[lst[0].id]].map do |i|
            next [i[@@id_j],total_prob] if i[@@doff] == 0
            total_prob +=  1.0 /(i[@@doff]*i[@@doff])
            next [i[@@id_j],total_prob]
          end
          r = (1.0-rand(0))*total_prob
          pnum = Agents.binary_search(prob_list,r,0){|item,thres| item[1] < r}
          redo if @@lock_list.include? prob_list[pnum][0]
          @@lock_list << prob_list[pnum][0]
          agent = @@agent_list.find(lambda{ raise "Agent not found!: Possible inconsistency between @@agent_list and the relationship_matrix."}){|item| item.id == prob_list[pnum][0]}
          next agent
        end
        lst.concat(lnd)
      end
      return lst
    end
  end
  
  def Agents.unchoose(*ids)
    @@lock_list.synchronize do
      @@total_count += 1
      result = ids.map{ |id| @@lock_list.delete(id)}
      raise "Inconsistant ids." if result.include? nil
      @@lock_list_cond_to_mon.signal
    end
  end
end
