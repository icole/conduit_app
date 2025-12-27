# frozen_string_literal: true

module SoftDeleteTestHelper
  def assert_soft_deleted(record)
    record.reload
    assert record.discarded?, "Expected #{record.class.name} ##{record.id} to be soft deleted"
  end

  def assert_not_soft_deleted(record)
    record.reload
    refute record.discarded?, "Expected #{record.class.name} ##{record.id} to NOT be soft deleted"
  end

  def assert_cascade_soft_deleted(parent, *associations)
    associations.each do |assoc|
      parent.send(assoc).with_discarded.each do |child|
        assert child.discarded?, "Expected associated #{assoc.to_s.singularize} ##{child.id} to be soft deleted"
      end
    end
  end
end
