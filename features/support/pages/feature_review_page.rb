module Pages
  class FeatureReviewPage
    def initialize(page:, url_helpers:)
      @page        = page
      @url_helpers = url_helpers
    end

    def app_info
      verify!
      Sections::PanelListSection.new(
        page.find('.app-info.panel'),
        item_config: {
          'app_name' => '.name',
          'version' => '.version',
        },
      ).items
    end

    def builds
      verify!
      Sections::TableSection.new(
        page.find('.builds table'),
        icon_translations: {
          'text-success' => 'success',
          'text-danger'  => 'failed',
          'text-warning' => 'warning',
        },
      ).items
    end

    def uat_url
      verify!
      page.find('.uat-url').text
    end

    def panel_heading_status(panel_class)
      verify!
      page.find(".panel.#{panel_class}")[:class].match(/panel-(?<status>\w+)/)[:status]
    end

    def deploys
      verify!
      Sections::TableSection.new(
        page.find('.deploys table'),
        icon_translations: {
          'text-success' => 'yes',
          'text-danger'  => 'no',
        },
      ).items
    end

    def create_qa_submission(status:, comment:)
      verify!
      page.choose(status.capitalize)
      page.fill_in('Comment', with: comment)
      page.click_link_or_button('Submit')
    end

    def qa_submission_panel
      verify!
      Sections::PanelListSection.new(
        page.find('.qa-submission.panel'),
        item_config: {
          'comment' => '.qa-comment',
          'email' => '.qa-email',
        },
      )
    end

    def tickets
      verify!
      Sections::TableSection.new(page.find('.feature-status table')).items
    end

    def uatest_panel
      verify!
      Sections::PanelListSection.new(
        page.find('.uatest.panel'),
        item_config: {
          'test_suite_version' => '.uat-version',
        },
      )
    end

    def summary_panel
      verify!
      Sections::PanelListSection.new(
        page.find('.summary'),
        item_config: {
          'title' => '.title',
          'status' => '.status',
        },
      )
    end

    def time
      verify!
      page.find('.time').text
    end

    private

    attr_reader :page, :url_helpers

    def verify!
      fail "Expected to be on a Feature Review page, but was on #{page.current_url}" unless on_page?
    end

    def on_page?
      page.current_url =~ Regexp.new(Regexp.escape(url_helpers.feature_reviews_path + '?'))
    end
  end
end
