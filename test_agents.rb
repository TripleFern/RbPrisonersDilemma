require "test/unit"
require "agents"
require "agent_status"

class Agents
  attr_accessor :replier
end

class TestAgents < Test::Unit::TestCase
  
  def setup
    if Agents.size == 0 then
      Agents.create(80,:sym_rand)
    end
  end
  
  def test_think
    a,b = Agents.choose(:use_relationship)
    (1..700).each do
      a_prior = 1.0 - rand(0)
      b_prior = 1.0 - rand(0)
      a_thought = a.think(a_prior)
      b_thought = b.think(b_prior)
      print "A, B id, prior, think:\t#{a.id}\t#{b.id}\t#{a_prior}\t#{b_prior}\t#{a_thought}\t#{b_thought}\n"
    end
  end
  
  def test_play
    i = 0
    ac = 0
    bc = 0
    (1..70).each do
      a,b = Agents.choose(:use_relationship)
      i += 1
      a_choice = a.play(b.id)
      b_choice = b.play(a.id)
      if a.replier != nil then
        print "A id, replier =\t\t#{a.id}\t#{a.replier}\n"
        ac += 1
      end
      if b.replier != nil then
        print "B id, replier =\t\t#{b.id}\t#{b.replier}\n"
        bc += 1
      end
      Agents.unchoose(a.id,b.id)
    end
    print "Asking ocurred (A, B) within total #{i} counts:(#{ac}, #{bc})"
  end
  
  def test_main_loop
    i = 0
    (1..100).each do
      i += 1
      print "." if i % 20 == 0
      a,b = Agents.choose(:use_relationship)
      a_choice = a.play(b.id)
      b_choice = b.play(a.id)
      print("A,B id,choice,point =\t" + a.id.to_s + "\t" + b.id.to_s + "\t" + a_choice.to_s + "\t" + b_choice.to_s + "\t")
      if a_choice >= b_choice then
        half = a_choice
      else
        half = b_choice
      end
      a_point = (b_choice/(a_choice+b_choice))*half*2
      b_point = (a_choice/(a_choice+b_choice))*half*2
      puts(a_point.to_s + "\t" + b_point.to_s)
      # Return results to agents.
      a.knotify_result(a_point,b.id,b_choice)
      b.knotify_result(b_point,a.id,a_choice)
      # Unlock current agents.
      Agents.unchoose(a.id,b.id)
    end
  end
end