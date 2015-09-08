module Pages
  class ReleasesPage
    def initialize(page:, url_helpers:)
      @page        = page
      @url_helpers = url_helpers
    end

    def visit(app)
      page.visit url_helpers.releases_path
      page.click_on(app)
    end

    def pending_releases
      verify!
      page.all('.pending-release').map { |release_line|
        values = release_line.all('td').to_a
        {
          'approved' => !release_line['class'].split.include?('danger'),
          'version' => values.fetch(0).text,
          'subject' => values.fetch(1).text,
          'feature_reviews' => values.fetch(2).text,
          'feature_review_paths' => extract_href_if_exists(values.fetch(2)),
        }
      }
    end

    def deployed_releases
      verify!
      page.all('.deployed-release').map { |release_line|
        values = release_line.all('td').to_a
        release = {
          'approved' => !release_line['class'].split.include?('danger'),
          'version' => values.fetch(0).text,
          'subject' => values.fetch(1).text,
          'feature_reviews' => values.fetch(2).text,
          'feature_review_paths' => extract_href_if_exists(values.fetch(2)),
          'time' => nil,
        }

        deploy_time = values.fetch(3).text
        release['time'] = Time.parse(deploy_time) unless deploy_time.empty?
        release
      }
    end

    private

    def extract_href_if_exists(element)
      element.all('a').map { |link| link['href'] }
    end

    def verify!
      fail "Expected to be on a Feature Review page, but was on #{page.current_url}" unless on_page?
    end

    def on_page?
      page.current_url =~ Regexp.new(Regexp.escape(url_helpers.releases_path))
    end

    attr_reader :page, :url_helpers
  end
end
