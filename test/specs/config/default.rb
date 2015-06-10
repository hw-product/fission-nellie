Configuration.new do
  fission do
    loaders do
      workers ['fission-nellie']
      sources ['carnivore-actor']
    end
    sources.nellie.type 'actor'
    workers.nellie 1
  end
end
