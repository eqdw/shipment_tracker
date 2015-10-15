module Pages
  class FeatureReviewSearchPage
    def initialize(page:, url_helpers:)
      @page        = page
      @url_helpers = url_helpers
    end

    def search_for(app:, version:)
      page.visit url_helpers.search_feature_reviews_path
      page.select app, from: 'Application'
      page.fill_in('version', with: version)
      page.click_button('Search')
    end

    def links
      verify!
      page.all('.feature_review_link').map { |feature_review_line| feature_review_line[:href] }
    end

    def click_nth_link(position)
      verify!
      link_num = position.to_i - 1
      page.all('.feature_review_link')[link_num].click
    end

    private

    def verify!
      fail "Expected to be on a Feature Review Search page, but was on #{page.current_url}" unless on_page?
    end

    def on_page?
      page.current_url =~ Regexp.new(Regexp.escape(url_helpers.search_feature_reviews_path))
    end

    attr_reader :page, :url_helpers
  end
end
