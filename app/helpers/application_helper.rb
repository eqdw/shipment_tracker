module ApplicationHelper
  def wiki_links(key)
    {
      home: 'https://github.com/FundingCircle/shipment_tracker/wiki',
      prepare: 'https://github.com/FundingCircle/shipment_tracker/wiki/1.-CREATING-A-FEATURE-REVIEW',
      review: 'https://github.com/FundingCircle/shipment_tracker/wiki/2.-ANALYSING-A-FEATURE-REVIEW',
      qa: 'https://github.com/FundingCircle/shipment_tracker/wiki/3.-QA-REVIEWS-FEATURE',
      releases: 'https://github.com/FundingCircle/shipment_tracker/wiki/5.-MERGING-AND-DEPLOYING-A-FEATURE',
      approve: 'https://github.com/FundingCircle/shipment_tracker/wiki/4.-PRODUCT-OWNER-REVIEWS-FEATURE',
      adding_tickets: 'https://github.com/FundingCircle/shipment_tracker/wiki/1.-CREATING-A-FEATURE-REVIEW#adding-jira-tickets-to-the-feature-review',
    }[key.to_sym]
  end

  def title(title_text = nil, options = {})
    haml_tag('h1.title') do
      haml_concat title_text

      help_url = options.delete(:help_url)
      align_right = options.delete(:align_right)
      help_link_icon(help_url, align_right) if help_url
    end
  end

  def short_sha(full_sha)
    full_sha[0...7]
  end

  def commit_link(version, github_repo_url)
    github_commit_url = "#{github_repo_url}/commit/#{version}"
    link_to short_sha(version), github_commit_url, target: '_blank'
  end

  def pull_request_link(commit_subject, github_repo_url)
    pull_request_num = commit_subject.scan(/pull request #(\d+)/).first.try(:first)
    if pull_request_num
      github_pull_request_url = "#{github_repo_url}/pull/#{pull_request_num}"
      pull_request_text = "pull request ##{pull_request_num}"
      link = link_to pull_request_text, github_pull_request_url, target: '_blank'
      commit_subject.sub(pull_request_text, link)
    else
      commit_subject
    end
  end

  def help_link_icon(url, align_right)
    classes = 'a.glyphicon.glyphicon-question-sign'
    classes << '.pull-right' if align_right
    haml_tag(
      classes,
      href: url, target: '_blank', title: 'Help'
    )
  end

  # Convenience method for working with ActiveModel::Errors.
  def error_message(attribute, message)
    return message.to_sentence if attribute == :base
    "#{attribute}: #{message.to_sentence}"
  end

  def panel(heading:, klass: nil, **options, &block)
    status_panel = options.key?(:status)
    status = options.delete(:status)
    classes = status_panel ? panel_class(status) : 'panel-info'

    haml_tag('.panel', class: [klass, classes]) do
      haml_tag(:div, class: 'panel-heading clearfix') do
        haml_tag(:div, class: 'panel-title pull-left') do
          heading_tag(heading, status, options[:help_url], options[:align_right], status_panel)
        end
        panel_heading_button(options[:button_link])
      end
      block.call
    end
  end

  def icon(classes)
    return unless classes
    attributes = { class: classes, aria: { hidden: true } }
    haml_tag('span.glyphicon', '', attributes)
  end

  private

  def panel_heading_button(button_hash)
    return unless button_hash
    haml_tag(:div, class: 'btn-group pull-right') do
      haml_tag(:a, class: 'btn btn-default btn-sm', href: button_hash.fetch(:url)) do
        haml_concat(button_hash.fetch(:text))
      end
    end
  end

  def heading_tag(heading, status, help_url, align_right, status_panel)
    haml_tag(:h2) do
      icon(icon_class(status)) if status_panel
      haml_concat(heading)
      help_link_icon(help_url, align_right) if help_url
    end
  end
end
