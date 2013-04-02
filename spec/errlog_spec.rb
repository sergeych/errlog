# logger_spec.rb

require 'spec_helper.rb'
require 'hashie'
require 'errlog'
require 'stringio'

describe Errlog do

  before :each do
    Errlog.configure 'TheTestId', '1234567890123456'
    @packager = Errlog.packager 'TheTestId', '1234567890123456'
  end

  it 'should have context' do
    Errlog.context.value = 'test'
    Errlog.context.value.should == 'test'
    Errlog.clear_context
    Errlog.context.value.should == nil
  end

  # This spec checks the whole chain - protect, exception, report, but does not check post
  it 'should provide protection' do
    Errlog.should_receive(:post).exactly(3).times do |payload|
      payload = Hashie::Mash.new payload
      payload.should_not be_nil
      payload.stack[0].should =~ /errlog_spec/
      payload.text.should == 'TestError'
      payload.time.should be_within(5000).of(Time.now)
      payload.component_name.should == 'test'
      payload.test.should == '123'
    end

    Errlog.protect 'test' do |ctx|
      Errlog.clear_context
      ctx.test = '123'
      raise 'TestError'
    end

    -> {
      Errlog.protect_rethrow 'test' do |ctx|
        ctx.test = '123'
        raise 'TestError'
      end
    }.should raise_error

    Errlog.context.test = '123'
    Errlog.report 'TestError'
  end

  it 'should provide logs' do
    Errlog.should_receive(:post).exactly(1).times do |payload|
      payload = Hashie::Mash.new payload
      payload.text.should == 'LogTest'
      payload.log.length.should == 2
      payload.log[0][3].should == 'test info'
      payload.log[1][3].should == 'test warning'
    end
    sio = StringIO.new
    l1 = Errlog::ChainLogger.new
    l2 = Errlog::ChainLogger.new Logger.new(sio)
    l1.info 'test info'
    l2.warn 'test warning'
    Errlog.report 'LogTest', Errlog::TRACE
    sio.string.should match( /W, \[.*\]  WARN -- : test warning/)
  end

  it 'should provide constants' do
    extend Errlog::Constants

    is_error?(Errlog::ERROR).should be_true
    is_error?(Errlog::WARNING).should_not be_true
    is_error?(Errlog::TRACE).should_not be_true


    is_warning?(Errlog::ERROR).should_not be_true
    is_warning?(Errlog::WARNING).should be_true
    is_warning?(Errlog::TRACE).should_not be_true
    
    is_trace?(Errlog::ERROR).should_not be_true
    is_trace?(Errlog::WARNING).should_not be_true
    is_trace?(Errlog::TRACE).should be_true

    Errlog.severity_name(Errlog::ERROR).should == 'error'
    Errlog.severity_name(Errlog::WARNING).should == 'warning'
    Errlog.severity_name(Errlog::TRACE).should == 'trace'
  end

end
