require 'spec_helper'
require 'errlog'

describe 'Packager' do

  before do
    @packager = Errlog.packager 'TheTestId', '1234567890123456'
  end

  it 'should properly cipher' do
    data  = 'The test data to encrypt/decrypt, just a test but long enough'
    cdata = @packager.encrypt data
    @packager.decrypt(cdata).should == data
  end

  it 'should accept base64-encoded keys too' do
    p2    = Errlog.packager 'TheOtherId', Base64.encode64('1234567890123456')
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
    p2 = Errlog.packager 'TheOtherId', Base64.encode64('123456789012345678901234')
    p2.unpack(data).should == nil
  end

  it 'should provide settings-driven packer' do
    Errlog.configure 'TheTestId', '1234567890123456'
    payload = { 'type' => 'log', 'payload' => 'The test payload again' }
    @packager.unpack(Errlog.pack(payload)).should == payload
  end

  it 'should unpack v1 packages' do
    # V1 format uses GZip stream, no encryption and sha256 signature
    b64 = 'AR+LCAAAAAAAAAOrVvJIzcnJV7KKVirPL8pJMVTSgTCMlGJrAQuX/j4dAAAAz/urvrAsvKusrC9PvECtQERrhNoH+95xE7EzR1HoThU='
    data = b64.unpack('m')[0]
    @packager = Errlog.packager 'TheTestId', '6rA/5Ud1WEYoTz3h9umdXw=='.unpack('m')[0]
    @packager.unpack(data).should == {'Hello' => ['world1', 'world2']}
  end
end