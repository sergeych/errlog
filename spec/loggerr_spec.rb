# logger_spec.rb

require 'spec_helper.rb'
require 'hashie'
require 'loggerr'
require 'stringio'

describe Loggerr do

  before :each do
    Loggerr.configure 'TheTestId', '1234567890123456'
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
    Loggerr.should_receive(:post).exactly(3).times do |payload|
      payload = Hashie::Mash.new payload
      payload.should_not be_nil
      payload.stack[0].should =~ /loggerr_spec/
      payload.text.should == 'RuntimeError: TestError'
      payload.time.should be_within(5000).of(Time.now)
      payload.component_name.should == 'test'
      payload.test.should == '123'
    end

    Loggerr.protect 'test' do |ctx|
      Loggerr.clear_context
      ctx.test = '123'
      raise 'TestError'
    end

    -> {
      Loggerr.protect_rethrow 'test' do |ctx|
        ctx.test = '123'
        raise 'TestError'
      end
    }.should raise_error

    Loggerr.context.test = '123'
    Loggerr.report 'RuntimeError: TestError'
  end

  it 'should provide logs' do
    Loggerr.should_receive(:post).exactly(1).times do |payload|
      payload = Hashie::Mash.new payload
      payload.text.should == 'LogTest'
      payload.log.length.should == 2
      payload.log[0][3].should == 'test info'
      payload.log[1][3].should == 'test warning'
    end
    sio = StringIO.new
    l1 = Loggerr.create_logger
    l2 = Loggerr.create_logger Logger.new(sio)
    l1.info 'test info'
    l2.warn 'test warning'
    Loggerr.report 'LogTest', Loggerr::TRACE
    sio.string.should match( /W, \[.*\]  WARN -- : test warning/)
  end

  it 'should provide constants' do
    extend Loggerr::Constants

    is_error?(Loggerr::ERROR).should be_true
    is_error?(Loggerr::WARNING).should_not be_true
    is_error?(Loggerr::TRACE).should_not be_true


    is_warning?(Loggerr::ERROR).should_not be_true
    is_warning?(Loggerr::WARNING).should be_true
    is_warning?(Loggerr::TRACE).should_not be_true
    
    is_trace?(Loggerr::ERROR).should_not be_true
    is_trace?(Loggerr::WARNING).should_not be_true
    is_trace?(Loggerr::TRACE).should be_true

    Loggerr.severity_name(Loggerr::ERROR).should == 'error'
    Loggerr.severity_name(Loggerr::WARNING).should == 'warning'
    Loggerr.severity_name(Loggerr::TRACE).should == 'trace'
  end

end
