=begin rdoc
relationship_matrix[i,j] = [id_i, id_j, distance, familiarity, opponent_strategy]
=end

class RelationshipMatrix
  
  private
  
  @@doff = 2
  @@famoff = 3
  
  def binary_tree_gen(matrix,tree,depth,num)
    return if num == 1
    car = tree.slice!(0,num/2)
    distance = 1.0/depth
    car.each do |i|
      tree.each do |j|
        matrix[i][j][@@doff] = distance
        matrix[i][j][@@famoff] = distance
        matrix[j][i][@@doff] = distance
        matrix[j][i][@@famoff] = distance
      end
    end
    binary_tree_gen(matrix,car,depth+1,car.size)
    binary_tree_gen(matrix,tree,depth+1,tree.size)
  end
  
  def regenerate(parent_num)
    return 1.0-rand(0) if parent_num == 0
    return parent_num+(parent_num*(1.0-parent_num)*(rand(0)-0.5))
  end
  
  public
  
  attr_reader :kinship
  
  def initialize
    @matrix = nil
    @kinship = nil
    @kinship_v = nil
  end
    
  def [](i)
    @matrix[i]
  end

  def populate (num,distance_type)
    case distance_type
    when :rand
      new_matrix = Array.new(num) do |i|
        row = Array.new
        (0..(num-1)).each do |j|
          if i == j then distance = 0
          else distance = 1.0-rand(0)
          end
          row << [i,j,distance,distance,nil] 
        end
        next row
      end
      
    when :sym_rand
      new_matrix = Array.new(num) do |i|
        row = Array.new
        (0..(num-1)).each do |j|
          if i < j then distance = 1.0-rand(0)
          else distance = 0
          end
          row << [i,j,distance,distance,nil] 
        end
        next row
      end
      (1..(num-1)).each do |i|
        (0..(i-1)).each do |j|
          new_matrix[i][j][@@doff]=new_matrix[j][i][@@doff]
          new_matrix[i][j][@@famoff]=new_matrix[j][i][@@famoff]
        end
      end
      
    when :topology
      new_matrix = Array.new(num) do |i|
        row = Array.new
        (0..(num-1)).each do |j|
          row << [i,j,0,0,nil] 
        end
        next row
      end
      incorporated = Array.new
      (1..num).each do |i|
        r = rand(num)
        break if incorporated.size == num
        redo if incorporated.include? r
        incorporated << r
      end
      binary_tree_gen(new_matrix,incorporated,1,num)
      
    when :uniform
      new_matrix = Array.new(num) do |i|
        row = Array.new
        (0..(num-1)).each do |j|
          if i == j then distance = 0
          else       distance = 1
          end
          row << [i,j,distance,distance,nil] 
        end
        next row
      end
    end
    return new_matrix
  end
  
  def update_kinship()
    @kinship = @matrix.map {|row| row.sort{|i,j| i[2]<=>j[2]}}
    @kinship_v = (0...@matrix.size).map do |i|
      column = @matrix.map{|row| row[i]}
      column.sort! {|i,j| i[3]<=>j[3]}
      next column
    end
  end

  def repopulate(num,distance_type,heredity=nil)
    
    if @matrix == nil then
      @matrix = populate(num,distance_type)
      update_kinship()
      return
    end
    
    case distance_type
    when :rand
      new_rows = Array.new
      heredity.each do |h|
        new_rows << @matrix[h[1]].map do |item|
          new_item = item.clone()
          new_item[0] = h[0]
          new_item[2] = regenerate(item[2])
          if item[3] == 0 then
            new_item[3] = @kinship[h[1]][1][3]/2.0
          end
          next new_item
        end
      end
      @matrix.each do |row|
        heredity.each do |h|
          new_item = row[h[1]].clone()
          new_item[1] = h[0]
          if row[h[1]][2] == 0 then
            new_item[2] = @kinship_v[h[1]][1][2]/2.0
          end
          if row[h[1]][3] == 0 then
            new_item[3] = @kinship_v[h[1]][1][3]/2.0
          end
          row << new_item
        end
      end
      novel = populate(num,:rand)
      heredity.each_index do |i|
        heredity.each_index do |j|
          novel[i][j][0] = heredity[i][0]
          novel[i][j][1] = heredity[j][0]
        end
      end
      new_rows.each do |row|
        novel_row = novel.shift
        row.concat(novel_row)
      end
      @matrix.concat(new_rows)
      update_kinship()
      
    when :sym_rand
      new_rows = Array.new
      heredity.each do |h|
        new_rows << @matrix[h[1]].map do |item|
          new_item = item.clone()
          new_item[0] = h[0]
          new_item[2] = regenerate(item[2])
          if item[3] == 0 then
            new_item[3] = @kinship[h[1]][1][3]/2.0
          end
          next new_item
        end
      end
      rep = @matrix.size
      @matrix.concat(new_rows)
      (0...rep).each do |ri|
        heredity.each_index do |hi|
          new_item = @matrix[ri][heredity[hi][1]].clone()
          new_item[1] = heredity[hi][0]
          new_item[2] = @matrix[rep+hi][ri][2]
          if @matrix[ri][heredity[hi][1]][3] == 0 then
            new_item[3] = @kinship_v[heredity[hi][1]][1][3]/2.0
          end
          @matrix[ri] << new_item
        end
      end
      novel = populate(num,:sym_rand)
      heredity.each_index do |i|
        heredity.each_index do |j|
          novel[i][j][0] = heredity[i][0]
          novel[i][j][1] = heredity[j][0]
        end
      end
      (rep...(rep+num)).each do |ri|
        novel_row = novel.shift
        @matrix[ri].concat(novel_row)
      end
      update_kinship()
      
    when :topology
      new_rows = Array.new
      heredity.each do |h|
        new_rows << @matrix[h[1]].map do |item|
          new_item = item.clone()
          new_item[0] = h[0]
          if item[2] == 0 then
            new_item[2] = @kinship[h[1]][1][2] /2.0 #-- Distance 0 is the one it self!
          end
          if item[3] == 0 then
            new_item[3] = @kinship[h[1]][1][3] /2.0 #-- Distance 0 is the one it self!
          end
          next new_item
        end
      end
      rep = @matrix.size
      @matrix.concat(new_rows)
      (0...rep).each do |ri|
        heredity.each_index do |hi|
          new_item = @matrix[ri][heredity[hi][1]].clone()
          new_item[1] = heredity[hi][0]
          new_item[2] = @matrix[rep+hi][ri][2]
          if @matrix[ri][heredity[hi][1]][3] == 0 then
            new_item[3] = @kinship_v[heredity[hi][1]][1][3]/2.0
          end
          @matrix[ri] << new_item
        end
      end
      novel = heredity.map do |u|
        novel_row = Array.new
        heredity.each do |v|
          novel_row << [u[0],v[0],@matrix[u[1]][v[1]][2],@matrix[u[1]][v[1]][3],nil]
        end
        next novel_row
      end
      (rep...(rep+num)).each do |ri|
        novel_row = novel.shift
        @matrix[ri].concat(novel_row)
      end
      update_kinship()
      
    when :uniform
      new_rows = Array.new
      heredity.each do |h|
        new_rows << @matrix[h[1]].map do |item|
          new_item = item.clone()
          new_item[0] = h[0]
          new_item[2] = 1 if item[2] == 0
          new_item[3] = 1 if item[3] == 0
          next new_item
        end
      end
      @matrix.each do |row|
        heredity.each do |h|
          new_item = row[h[1]].clone()
          new_item[1] = h[0]
          new_item[2] = 1 if row[h[1]][2] == 0
          new_item[3] = 1 if row[h[1]][3] == 0
          row << new_item
        end
      end
      novel = populate(num,:rand)
      heredity.each_index do |i|
        heredity.each_index do |j|
          novel[i][j][0] = heredity[i][0]
          novel[i][j][1] = heredity[j][0]
        end
      end
      new_rows.each do |row|
        novel_row = novel.shift
        row.concat(novel_row)
      end
      @matrix.concat(new_rows)
      update_kinship()
      
    end
  end
  
  def remove(list,id2off)
    return if list.size == 0
    list.sort!
    x_row = list.clone()
    k = x_row.shift
    new_matrix = Array.new
    @matrix.each_index do |i|
      if i == k then
        k = x_row.shift
        next
      end
      sl = 0
      row = Array.new
      list.each_index do |t|
        if sl == list[t] then
          sl = list[t]+1
          next
        end
        row.concat(@matrix[i][sl..(list[t]-1)])
        sl = list[t]+1
      end
      row.concat(@matrix[i][sl..-1]) unless sl == @matrix[i].size
      new_matrix << row
    end
    @matrix = new_matrix
    update_kinship()
    
    sl = 0
    sh_a = Array.new
    list.each_index do |t|
      sh_a.concat(Array.new(list[t]-sl,t)) unless sl == list[t]
      sh_a << -1
      sl = list[t]+1
    end
    sh_a.concat(Array.new(id2off.size-sh_a.size,list.size)) unless sl == id2off.size
    id2off.each do |key,val|
      if sh_a[val] < 0 then
        id2off.delete(key)
        next
      end
      id2off[key] = val-sh_a[val]
    end
    
  end
  
end
