# frozen_string_literal: true

class AdminAiWorkflowTabsComponent < ViewComponent::Base
  def initialize(snapshot:, tab:, events_page:, events_per_page:)
    @snapshot = snapshot
    @tab = tab
    @events_page = events_page
    @events_per_page = events_per_page
  end

  def tab_active?(name)
    @tab == name
  end

  def events
    return [] unless @snapshot
    @snapshot.events
  end

  def paged_events
    offset = (@events_page - 1) * @events_per_page
    events.slice(offset, @events_per_page) || []
  end

  def has_prev?
    @events_page > 1
  end

  def has_next?
    (@events_page * @events_per_page) < events.length
  end
end
