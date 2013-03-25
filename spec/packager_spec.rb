require 'spec_helper'
require 'loggerr/packager'
require 'loggerr'
require 'hashie'

describe 'Packager' do

  before do
    @packager = Loggerr.packager 'TheTestId', '1234567890123456'
  end

  it 'should properly cipher' do
    data  = 'The test data to encrypt/decrypt, just a test but long enough'
    cdata = @packager.encrypt data
    @packager.decrypt(cdata).should == data
  end

  it 'should accept base64-encoded keys too' do
    p2    = Loggerr.packager 'TheOtherId', Base64.encode64('1234567890123456')
    data  = 'The test data to encrypt/decrypt, just a test but long enough, and for another purpose'
    cdata = @packager.encrypt data
    p2.decrypt(cdata).should == data
  end


  it 'should create and parse the package' do
    payload = { 'type' => 'log', 'payload' => 'The test payload' }
    data    = @packager.pack payload
    @packager.unpack(data).should == payload
  end

  it 'should check that package is valid (signed)' do
    payload = { 'type' => 'log', 'payload' => 'The test payload' }
    data    = @packager.pack payload
    p2 = Loggerr.packager 'TheOtherId', Base64.encode64('123456789012345678901234')
    p2.unpack(data).should == nil
  end

  it 'should provide settings-driven packer' do
    Loggerr.configure 'TheTestId', '1234567890123456'
    payload = { 'type' => 'log', 'payload' => 'The test payload again' }
    @packager.unpack(Loggerr.pack(payload)).should == payload
  end

  it 'should have context' do
    Loggerr.context.value = 'test'
    Loggerr.context.value.should == 'test'
    Loggerr.clear_context
    Loggerr.context.value.should == nil
  end

  it 'should provide protection' do
    Loggerr.configure 'TheTestId', '1234567890123456'
    Loggerr.should_receive(:post).exactly(2).times do |arg|
      payload = Hashie::Mash.new @packager.unpack(arg)
      puts payload.inspect
      payload.should_not be_nil
      payload.stack[0].should =~ /packager_spec/
      payload.exception.should == 'TestError'
      payload.exception_class.should == 'RuntimeError'
      payload.time.should be_within(5000).of(Time.now)
      payload.component_name.should == 'test'
    end

    Loggerr.protect 'test' do
      raise 'TestError'
    end

    -> {
      Loggerr.protect_rethrow 'test' do
        raise 'TestError'
      end
    }.should raise_error
  end

end