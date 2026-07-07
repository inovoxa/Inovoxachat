json.payload do
  json.array! @pipeline_stages do |stage|
    json.partial! 'pipeline_stage', pipeline_stage: stage
  end
end
