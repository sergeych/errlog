# logger_spec.rb

require 'spec_helper.rb'
require 'hashie'
require 'loggerr'

describe Loggerr do

  before do
    @packager = Loggerr.packager 'TheTestId', '1234567890123456'
  end

  it 'should have context' do
    Loggerr.context.value = 'test'
    Loggerr.context.value.should == 'test'
    Loggerr.clear_context
    Loggerr.context.value.should == nil
  end

  # This spec checks the whole chain - protect, report_exception, report, but does not check post
  it 'should provide protection' do
    Loggerr.configure 'TheTestId', '1234567890123456'
    Loggerr.should_receive(:post).exactly(2).times do |arg|
      payload = Hashie::Mash.new @packager.unpack(arg)
      payload.should_not be_nil
      payload.stack[0].should =~ /loggerr_spec/
      payload.text.should == 'RuntimeError: TestError'
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
