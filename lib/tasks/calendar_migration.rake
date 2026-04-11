# frozen_string_literal: true

namespace :calendar do
  desc "Migrate events from old personal calendar to new org calendar"
  task :migrate_events, [ :source_calendar_id ] => :environment do |_t, args|
    source_calendar_id = args[:source_calendar_id]
    abort "Usage: rails calendar:migrate_events[SOURCE_CALENDAR_EMAIL]" unless source_calendar_id.present?

    dest_calendar_id = ENV["GOOGLE_CALENDAR_ID"]
    abort "GOOGLE_CALENDAR_ID not set" unless dest_calendar_id.present?

    puts "Migrating events from #{source_calendar_id} to #{dest_calendar_id}"
    puts "=" * 60

    # Source: service account reads as itself (calendar shared with it)
    source_creds = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: CalendarCredentials.credentials_io,
      scope: "https://www.googleapis.com/auth/calendar.readonly"
    )
    source_service = Google::Apis::CalendarV3::CalendarService.new
    source_service.authorization = source_creds

    # Dest: service account impersonates org user via delegation
    dest_creds = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: CalendarCredentials.credentials_io,
      scope: "https://www.googleapis.com/auth/calendar"
    )
    dest_creds.sub = ENV["GOOGLE_IMPERSONATE_EMAIL"]
    dest_service = Google::Apis::CalendarV3::CalendarService.new
    dest_service.authorization = dest_creds

    # Fetch all events from source
    time_min = Time.zone.parse("2025-01-01").beginning_of_day
    time_max = Time.zone.parse("2026-12-31").end_of_day

    puts "Fetching events from #{time_min.to_date} to #{time_max.to_date}..."

    all_events = []
    page_token = nil

    loop do
      response = source_service.list_events(
        source_calendar_id,
        single_events: false,
        time_min: time_min.iso8601,
        time_max: time_max.iso8601,
        max_results: 2500,
        page_token: page_token
      )

      all_events.concat(response.items || [])
      page_token = response.next_page_token
      break unless page_token
    end

    puts "Found #{all_events.length} events in source calendar"

    # Fetch existing events on dest to avoid duplicates (match by summary + start time)
    existing_events = Set.new
    page_token = nil

    loop do
      response = dest_service.list_events(
        dest_calendar_id,
        single_events: false,
        time_min: time_min.iso8601,
        time_max: time_max.iso8601,
        max_results: 2500,
        page_token: page_token
      )

      (response.items || []).each do |event|
        start_key = event.start&.date_time&.iso8601 || event.start&.date.to_s
        existing_events.add("#{event.summary}||#{start_key}")
      end

      page_token = response.next_page_token
      break unless page_token
    end

    puts "Found #{existing_events.length} existing events on destination (for duplicate check)"
    puts "-" * 60

    copied = 0
    skipped = 0
    errors = 0

    all_events.each do |event|
      start_key = event.start&.date_time&.iso8601 || event.start&.date.to_s
      dup_key = "#{event.summary}||#{start_key}"

      if existing_events.include?(dup_key)
        skipped += 1
        next
      end

      # Skip cancelled events
      if event.status == "cancelled"
        skipped += 1
        next
      end

      # Build new event, preserving relevant fields
      attrs = {
        summary: event.summary,
        description: event.description,
        location: event.location,
        start: event.start,
        end: event.end
      }
      attrs[:recurrence] = event.recurrence if event.recurrence.present?
      attrs[:color_id] = event.color_id if event.color_id.present?

      new_event = Google::Apis::CalendarV3::Event.new(**attrs)

      begin
        dest_service.insert_event(dest_calendar_id, new_event)
        copied += 1
        puts "  Copied: #{event.summary} (#{start_key})"
      rescue Google::Apis::ClientError => e
        errors += 1
        puts "  ERROR: #{event.summary} - #{e.message}"
      end
    end

    puts "=" * 60
    puts "Migration complete: #{copied} copied, #{skipped} skipped, #{errors} errors"
  end
end
