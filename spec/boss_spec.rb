require 'spec_helper'
require 'loggerr'

describe 'Boss' do

  it 'should perform compatible encode' do
    Vectors.each do |a, b|
      Boss.load(a).should == b
    end
  end

  it 'should perform compatible decode' do
    Vectors.each do |a,b|
      Boss.load(a).should == b
    end
  end

  it 'should properly encode nil' do
      round_check(1)
      round_check(nil)
      round_check([1])
      round_check([nil,nil,nil,3,4,5, nil])
  end

  it 'should cache data' do
    a = [1,2,3,4]
    ca = { 1 => 55 }
    b, c, d, e, f, g = Boss.load(Boss.dump([a,a,ca,ca, "oops", "oops"]))
    a.should == b
    b.should == c
    b.should be_eql(c)

    ca.should == d
    ca.should == e
    d.should be_equal(e)

    f.should == "oops"
    g.should == f
    g.should be_equal(f)
  end

  it 'should properly encode very big integers' do
    val = 1<<1024 * 7 + 117
    round_check val
  end

  it 'should decode one by one using block' do
    args = [1,2,3,4,5]
    s = Boss.dump(*args)
    res = []
    res = Boss.load(s) { |x| x }
    args.should == res
  end

  it 'should cache arrays and hashes too' do
    d = { "Hello" => "world" }
    a = [112,11]
    r = Boss.load_all(Boss.dump( a,d,a,d ))
    [a,d,a,d].should == r
    r[1].should be_equal(r[3])
    r[0].should be_equal(r[2])
  end


  def round_check(ob)
    ob.should == Boss.load(Boss.dump(ob))
  end


  ##
  # Set (force) string str encoding to binary
  def self.bytes!(str)
    str.force_encoding Encoding::BINARY
    str
  end

  Vectors = [['8', 7], ["\xb8F", 70], [".\x00\x08\n8:", [0, 1, -1, 7, -7]], ["\xc8p\x11\x01", 70000],
             ['+Hello', 'Hello'], [',Hello', bytes!('Hello'), 2, 4, 4, 1]]


  class TestCaseBoss


    def testEnum
      d = { "Hello" => "world" }
      a = [112,11]
      s = Boss.dump( a,d,a,d )
      r = Array(Parser.new(s))
      assert_equal [a,d,a,d], r
      assert r[1].eql?(r[3])
      assert r[0].eql?(r[2])
    end
  end
end