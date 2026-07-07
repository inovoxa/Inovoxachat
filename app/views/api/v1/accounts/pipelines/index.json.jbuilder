json.payload do
  json.array! @pipelines do |pipeline|
    json.partial! 'pipeline', pipeline: pipeline
  end
end
