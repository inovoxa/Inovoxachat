json.id pipeline.id
json.name pipeline.name
json.description pipeline.description
json.template_key pipeline.template_key
json.auto_add_mode pipeline.auto_add_mode
json.stages pipeline.pipeline_stages do |stage|
  json.partial! 'api/v1/accounts/pipeline_stages/pipeline_stage', pipeline_stage: stage
end
