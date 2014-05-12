describe 'Fission::Nellie' do
  before do
    @cwd = File.dirname(__FILE__)
    Carnivore::Config.configure(:config_path => File.join(@cwd, 'config/pending.json'))
    @runner = Thread.new do
      require 'fission/runner'
    end
    source_wait(:setup)
  end

  after do
    @runner.terminate
  end

  it 'should fire a webhook while build is pending' do
    Carnivore::Supervisor.supervisor[:nellie].transmit(payload_for(:pending, :raw => true))
    source_wait(5)
    MessageStore.messages.size.must_be :>, 2
  end

end
