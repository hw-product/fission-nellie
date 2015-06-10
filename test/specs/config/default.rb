Configuration.new do
  fission do
    loaders do
      workers ['fission-nellie/melba']
      sources ['carnivore-actor']
    end
    sources.nellie.type 'actor'
    workers.nellie.melba 1
  end
end
