require 'spec_helper'
#require 'loggerr'
require 'loggerr/packager'

describe 'Packager' do

  before do
    @packager = Loggerr::Packager.new 'TheTestId', '1234567890123456'
  end

  it 'should properly cipher' do
    data = "The test data to encrypt/decrypt, just a test but long enough"
    cdata = @packager.encrypt data
    @packager.decrypt(cdata).should == data
  end

  it 'should accept base64-encoded keys too' do
    p2 = Loggerr::Packager.new "TheOtherId", Base64.encode64("1234567890123456")
    data = "The test data to encrypt/decrypt, just a test but long enough, and for another purpose"
    cdata = @packager.encrypt data
    p2.decrypt(cdata).should == data
  end

end