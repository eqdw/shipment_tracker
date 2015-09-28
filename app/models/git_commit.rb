require 'virtus'

class GitCommit
  include Virtus.value_object

  values do
    attribute :id, String
    attribute :author_name, String
    attribute :message, String
    attribute :time, Time
    attribute :parent_ids, Array
  end

  def subject_line
    message.split("\n").first
  end

  def associated_ids
    [id, parent_ids.second].compact
  end
end
