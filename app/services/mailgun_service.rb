class MailgunService
  class MailgunError < StandardError; end

  def initialize
    @api_key = ENV["MAILGUN_API_KEY"]
    @domain = ENV["MAILGUN_DOMAIN"]
    
    unless @api_key && @domain
      raise MailgunError, "MAILGUN_API_KEY and MAILGUN_DOMAIN must be set"
    end
    
    @client = Mailgun::Client.new(@api_key)
  end

  def create_mailing_list(name, description)
    list_address = "#{name}@#{@domain}"
    
    begin
      @client.post("lists", {
        address: list_address,
        name: name,
        description: description,
        access_level: "members"
      })
      
      Rails.logger.info "Created Mailgun mailing list: #{list_address}"
      list_address
    rescue Mailgun::CommunicationError => e
      Rails.logger.error "Failed to create Mailgun mailing list #{name}: #{e.message}"
      raise MailgunError, "Failed to create mailing list: #{e.message}"
    end
  end

  def update_mailing_list(list_address, name: nil, description: nil)
    params = {}
    params[:name] = name if name
    params[:description] = description if description
    
    return list_address if params.empty?
    
    begin
      @client.put("lists/#{list_address}", params)
      Rails.logger.info "Updated Mailgun mailing list: #{list_address}"
      list_address
    rescue Mailgun::CommunicationError => e
      Rails.logger.error "Failed to update Mailgun mailing list #{list_address}: #{e.message}"
      raise MailgunError, "Failed to update mailing list: #{e.message}"
    end
  end

  def delete_mailing_list(list_address)
    begin
      @client.delete("lists/#{list_address}")
      Rails.logger.info "Deleted Mailgun mailing list: #{list_address}"
      true
    rescue Mailgun::CommunicationError => e
      Rails.logger.error "Failed to delete Mailgun mailing list #{list_address}: #{e.message}"
      raise MailgunError, "Failed to delete mailing list: #{e.message}"
    end
  end

  def add_member(list_address, email_address, name: nil)
    params = {
      address: email_address,
      subscribed: "yes"
    }
    params[:name] = name if name
    
    begin
      @client.post("lists/#{list_address}/members", params)
      Rails.logger.info "Added member #{email_address} to #{list_address}"
      true
    rescue Mailgun::CommunicationError => e
      Rails.logger.error "Failed to add member #{email_address} to #{list_address}: #{e.message}"
      raise MailgunError, "Failed to add member: #{e.message}"
    end
  end

  def remove_member(list_address, email_address)
    begin
      @client.delete("lists/#{list_address}/members/#{email_address}")
      Rails.logger.info "Removed member #{email_address} from #{list_address}"
      true
    rescue Mailgun::CommunicationError => e
      Rails.logger.error "Failed to remove member #{email_address} from #{list_address}: #{e.message}"
      raise MailgunError, "Failed to remove member: #{e.message}"
    end
  end

  def send_message(list_address, from_name, subject, text_body, html_body = nil)
    from_address = "#{from_name} <#{list_address}>"
    
    params = {
      from: from_address,
      to: list_address,
      subject: subject,
      text: text_body
    }
    params[:html] = html_body if html_body
    
    begin
      result = @client.post("#{@domain}/messages", params)
      Rails.logger.info "Sent message to #{list_address}: #{subject}"
      result
    rescue Mailgun::CommunicationError => e
      Rails.logger.error "Failed to send message to #{list_address}: #{e.message}"
      raise MailgunError, "Failed to send message: #{e.message}"
    end
  end

  def get_list_info(list_address)
    begin
      @client.get("lists/#{list_address}")
    rescue Mailgun::CommunicationError => e
      Rails.logger.error "Failed to get info for #{list_address}: #{e.message}"
      raise MailgunError, "Failed to get list info: #{e.message}"
    end
  end

  def get_list_members(list_address)
    begin
      @client.get("lists/#{list_address}/members")
    rescue Mailgun::CommunicationError => e
      Rails.logger.error "Failed to get members for #{list_address}: #{e.message}"
      raise MailgunError, "Failed to get list members: #{e.message}"
    end
  end
end