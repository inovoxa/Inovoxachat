json.id pipeline.id
json.name pipeline.name
json.description pipeline.description
json.template_key pipeline.template_key
json.auto_add_mode pipeline.auto_add_mode
json.inbox_ids pipeline.inbox_ids
json.inboxes pipeline.inboxes do |inbox|
  json.id inbox.id
  json.name inbox.name
end
json.stages pipeline.pipeline_stages do |stage|
  json.partial! 'api/v1/accounts/pipeline_stages/pipeline_stage', pipeline_stage: stage
end
