module ApplicationHelper
  def title(title_text = nil, &block)
    haml_tag('h1.title', title_text, &block)
  end

  def short_sha(full_sha)
    full_sha[0...7]
  end

  # Convenience method for working with ActiveModel::Errors.
  def error_message(attribute, message)
    return message.to_sentence if attribute == :base
    "#{attribute}: #{message.to_sentence}"
  end
end
