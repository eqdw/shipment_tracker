module FeatureReviewsHelper
  def panel(heading:, klass: nil, **options, &block)
    status_panel = options.key?(:status)
    status = options.delete(:status)
    classes = status_panel ? panel_class(status) : 'panel-info'

    haml_tag('.panel', class: [klass, classes]) do
      haml_tag('.panel-heading') do
        haml_tag('h2') do
          icon(icon_class(status)) if status_panel
          haml_concat heading
        end
      end
      block.call
    end
  end

  def icon(classes, tooltip: nil)
    return unless classes
    attributes = { class: classes, aria: { hidden: true } }
    attributes.merge!(data: { toggle: 'tooltip' }, title: tooltip) if tooltip
    haml_tag('span.glyphicon', '', attributes)
  end

  def table(headers: [], classes: nil, &block)
    haml_tag('table.table.table-striped', class: classes) do
      haml_tag('thead') do
        haml_tag('tr') do
          headers.each do |header|
            haml_tag('th', header)
          end
        end
      end
      haml_tag('tbody', &block)
    end
  end

  def panel_class(status)
    "panel-#{item_class(status)}"
  end

  def text_class(status)
    "text-#{item_class(status)}"
  end

  def icon_class(status)
    "icon-#{item_class(status)}"
  end

  def item_status_icon_class(status)
    "#{icon_class(status)} status #{text_class(status)}"
  end

  def item_class(status)
    return 'success' if status == true
    return 'danger' if status == false

    case status && status.to_sym
    when :success
      'success'
    when :failure, :failed
      'danger'
    else
      'warning'
    end
  end

  def short_sha(full_sha)
    full_sha[0...7]
  end

  def to_link(url, options = {})
    link_to url, Addressable::URI.heuristic_parse(url).to_s, options
  end
end
