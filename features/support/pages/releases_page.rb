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
          'version' => commit_link(values.fetch(0)),
          'subject' => values.fetch(1).text,
          'feature_reviews' => values.fetch(2).text,
          'feature_review_paths' => extract_href(values.fetch(2)),
        }
      }
    end

    def deployed_releases
      verify!
      page.all('.deployed-release').map { |release_line|
        values = release_line.all('td').to_a
        {
          'approved' => !release_line['class'].split.include?('danger'),
          'version' => commit_link(values.fetch(0)),
          'subject' => values.fetch(1).text,
          'feature_reviews' => values.fetch(2).text,
          'feature_review_paths' => extract_href(values.fetch(2)),
          'time' => extract_time(values.fetch(3)),
        }
      }
    end

    private

    def commit_link(cell_element)
      link = find_valid_link(cell_element)
      return cell_element.text unless link
      "[#{link.text}](#{link[:href]})"
    end

    def find_valid_link(element)
      return unless element.has_css?('a')
      link = element.find('a')
      link[:href] == '#' ? nil : link
    end

    def extract_time(element)
      Time.zone.parse(element.text) unless element.text.empty?
    end

    def extract_href(element)
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
