require "test_helper"

class DocumentFoldersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_user
    @folder = document_folders(:root_folder)
  end

  test "should create folder" do
    assert_difference("DocumentFolder.count") do
      post document_folders_url, params: { document_folder: { name: "New Folder" } }
    end

    assert_redirected_to documents_url
  end

  test "should create nested folder" do
    assert_difference("DocumentFolder.count") do
      post document_folders_url, params: { document_folder: { name: "Subfolder", parent_id: @folder.id } }
    end

    folder = DocumentFolder.last
    assert_equal @folder, folder.parent
    assert_redirected_to documents_url(folder_id: @folder.id)
  end

  test "should update folder" do
    patch document_folder_url(@folder), params: { document_folder: { name: "Renamed" } }

    @folder.reload
    assert_equal "Renamed", @folder.name
    assert_redirected_to documents_url(folder_id: @folder.parent_id)
  end

  test "should destroy folder" do
    folder = DocumentFolder.create!(name: "To Delete", community: communities(:crow_woods))

    assert_difference("DocumentFolder.count", -1) do
      delete document_folder_url(folder)
    end

    assert_redirected_to documents_url
  end

  test "destroy should redirect to parent folder" do
    child = DocumentFolder.create!(name: "Child", parent: @folder, community: communities(:crow_woods))

    delete document_folder_url(child)

    assert_redirected_to documents_url(folder_id: @folder.id)
  end

  test "should not create folder with blank name" do
    assert_no_difference("DocumentFolder.count") do
      post document_folders_url, params: { document_folder: { name: "" } }
    end

    assert_response :unprocessable_entity
  end
end
