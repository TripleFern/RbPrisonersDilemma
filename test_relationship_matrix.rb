require "test/unit"
require "relationship_matrix"

class TestRelationshipMatrix < Test::Unit::TestCase
  def test_sym_random
    relation = RelationshipMatrix.new
    relation.repopulate(10,:sym_rand)
    relation.kinship.each{|row| p row}
  end
end