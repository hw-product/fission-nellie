describe Fission::Nellie do

  before do
    @runner = run_setup(:default)
  end

  after do
    @runner.terminate if @runner && @runner.alive?
  end

  it 'should providing a running nellie source' do
    Carnivore::Supervisor.supervisor[:nellie].name.must_equal :nellie
  end

end
