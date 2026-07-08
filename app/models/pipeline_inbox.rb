# == Schema Information
#
# Table name: pipeline_inboxes
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  inbox_id    :bigint           not null
#  pipeline_id :bigint           not null
#
class PipelineInbox < ApplicationRecord
  belongs_to :pipeline
  belongs_to :inbox
end
