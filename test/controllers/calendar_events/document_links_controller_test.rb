require "test_helper"

class CalendarEvents::DocumentLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @calendar_event = calendar_events(:one)
    @document = documents(:one)
    sign_in_user
  end

  test "should create document link" do
    post calendar_event_document_links_url(@calendar_event), params: { document_id: @document.id }
    assert_redirected_to calendar_event_url(@calendar_event)
  end

  test "should destroy document link" do
    @calendar_event.documents << @document

    delete calendar_event_document_link_url(@calendar_event, @document)
    assert_redirected_to calendar_event_url(@calendar_event)
  end
end
