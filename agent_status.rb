require "csv"
require "erb"
require "drb/drb"
require "rinda/rinda"

class AgentStatus
  
  def refresh
    @happiness_stat = Array.new
    @hprec = 10
    (1..@hprec).each{@happiness_stat << 0}
    @default_opponent_strategy_sum = 0
    @happiness_sum = 0
    @weight_sum = 0
    @div_sum = 0
    @count_sum = 0
    @listen_sum = 0
    @listen_weight_sum = 0
    @genotype_stat = Hash.new(0)
  end
  
  def initialize(type=:text)
    refresh()
    @text_template_stat = File.read("text_template_stat.txt")
    @text_template_happiness = File.read("text_template_happiness.txt")
    @erb_stat = ERB.new(@text_template_stat,nil,'-')
    @erb_happiness = ERB.new(@text_template_happiness,nil,'-')
    @report_type = type
  end
  
#[i.id, i.default_opponent_strategy, i.happiness,
# i.weight, i.div, i.count, i.genotype, i.listen, i.listen_weight]}  
# strategy: 0.0 .. 1.0
# point/happiness: 0.0 .. 2.0

  def update(agents_overview, total_count)
    refresh()
    agents_overview.each do |i|
      @default_opponent_strategy_sum += i[1]
      @happiness_sum += i[2]
      @weight_sum += i[3]
      @div_sum += i[4]
      @count_sum += i[5]
      @listen_sum += i[7]
      @listen_weight_sum += i[8]
      @happiness_stat[(i[2]*@hprec/2.0).floor] += 1
      @genotype_stat[i[6][0]] += 1
    end
    @default_opponent_strategy_avg = @default_opponent_strategy_sum/agents_overview.size
    @happiness_avg = @happiness_sum/agents_overview.size
    @weight_avg = @weight_sum/agents_overview.size
    @div_avg = @div_sum/agents_overview.size
    @count_avg = @count_sum/agents_overview.size
    @listen_avg = @listen_sum/agents_overview.size
    @listen_weight_avg = @listen_weight_sum/agents_overview.size
    @erb_stat.run(binding)
    @erb_happiness.run(binding) 
  end
  
end