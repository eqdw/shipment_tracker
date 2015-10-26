module Pages
  class PrepareFeatureReviewPage
    def initialize(page:, url_helpers:)
      @page        = page
      @url_helpers = url_helpers
    end

    def visit
      page.visit url_helpers.new_feature_reviews_path
    end

    def add(field_name:, content:)
      verify!
      page.fill_in(field_name, with: content)
    end

    def submit
      verify!
      page.click_link_or_button('Submit')
    end

    private

    attr_reader :page, :url_helpers

    def verify!
      fail "Expected to be on Prepare Feature Review page, but was on #{page.current_url}" unless on_page?
    end

    def on_page?
      page.current_url =~ Regexp.new(Regexp.escape(url_helpers.new_feature_reviews_path))
    end
  end
end
