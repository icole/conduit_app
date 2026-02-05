require "test_helper"

class DocumentFolderTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = communities(:crow_woods)
    @root_folder = document_folders(:root_folder)
    # Create nested folders in setup to avoid fixture FK ordering issues
    @nested_folder = DocumentFolder.create!(
      name: "2024",
      parent: @root_folder,
      community: communities(:crow_woods)
    )
    @deeply_nested = DocumentFolder.create!(
      name: "January",
      parent: @nested_folder,
      community: communities(:crow_woods)
    )
  end

  test "should require name" do
    folder = DocumentFolder.new(community: communities(:crow_woods))
    assert_not folder.valid?
    assert_includes folder.errors[:name], "can't be blank"
  end

  test "should create valid folder" do
    folder = DocumentFolder.new(
      name: "Test Folder",
      community: communities(:crow_woods)
    )
    assert folder.valid?
  end

  test "should belong to parent folder" do
    assert_equal @root_folder, @nested_folder.parent
  end

  test "should have children" do
    assert_includes @root_folder.children, @nested_folder
  end

  test "root? returns true for folders without parent" do
    assert @root_folder.root?
  end

  test "root? returns false for nested folders" do
    assert_not @nested_folder.root?
  end

  test "ancestors returns path to root" do
    ancestors = @deeply_nested.ancestors

    assert_equal 2, ancestors.length
    assert_equal @nested_folder, ancestors.first
    assert_equal @root_folder, ancestors.last
  end

  test "ancestors returns empty array for root folder" do
    assert_empty @root_folder.ancestors
  end

  test "path returns array from root to self" do
    path = @deeply_nested.path

    assert_equal 3, path.length
    assert_equal @root_folder, path.first
    assert_equal @nested_folder, path.second
    assert_equal @deeply_nested, path.last
  end

  test "depth returns 0 for root folder" do
    assert_equal 0, @root_folder.depth
  end

  test "depth returns correct level for nested folders" do
    assert_equal 1, @nested_folder.depth
    assert_equal 2, @deeply_nested.depth
  end

  test "should have many documents" do
    document = documents(:native_doc)
    document.update!(document_folder: @root_folder)

    assert_includes @root_folder.documents, document
  end

  test "destroying folder nullifies document folder_id" do
    document = documents(:native_doc)
    document.update!(document_folder: @deeply_nested)

    @deeply_nested.destroy

    document.reload
    assert_nil document.document_folder_id
  end

  test "destroying folder destroys children" do
    nested_id = @nested_folder.id
    deeply_nested_id = @deeply_nested.id

    @root_folder.destroy

    assert_nil DocumentFolder.find_by(id: nested_id)
    assert_nil DocumentFolder.find_by(id: deeply_nested_id)
  end

  test "should validate uniqueness of name within same parent" do
    duplicate = DocumentFolder.new(
      name: @nested_folder.name,
      parent: @root_folder,
      community: communities(:crow_woods)
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "tree_ordered returns folders in depth-first order" do
    # Create a second root-level folder that sorts alphabetically before "Meeting Notes"
    another_root = DocumentFolder.create!(
      name: "Budgets",
      community: communities(:crow_woods)
    )
    child_of_another = DocumentFolder.create!(
      name: "2025",
      parent: another_root,
      community: communities(:crow_woods)
    )

    ordered = DocumentFolder.tree_ordered

    # Should be: Budgets, 2025, Meeting Notes, 2024, January
    assert_equal [ another_root, child_of_another, @root_folder, @nested_folder, @deeply_nested ], ordered
  end

  test "allows same name in different parent folders" do
    folder1 = DocumentFolder.create!(
      name: "Reports",
      community: communities(:crow_woods)
    )
    folder2 = DocumentFolder.new(
      name: "Reports",
      parent: @root_folder,
      community: communities(:crow_woods)
    )

    assert folder2.valid?
  end
end
