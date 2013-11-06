require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require "redis"
require "rollout"
require "yajl"

describe "RolloutRestApi" do
  class FakeUser < Struct.new(:id); end

  def app
    RolloutRestAPI
  end

  before do
    @redis = Redis.new
    @redis.flushdb
    @rollout = Rollout.new(@redis)
    RolloutRestAPI.rollout = @rollout
  end

  it "gets /:feature.json" do
    get "/chat.json"

    last_response.should be_ok
    last_response.body.should == Yajl::Encoder.encode(@rollout.get(:chat).to_hash)
  end

  it "adds a group" do
    put "/chat/groups", :group => "caretakers"
    last_response.should be_ok
    @rollout.get(:chat).groups.should include(:caretakers)
  end

  it "removes a group" do
    @rollout.activate_group(:chat, :caretakers)
    @rollout.activate_group(:chat, :greeters)

    delete "/chat/groups", :group => "caretakers"
    last_response.should be_ok
    @rollout.get(:chat).groups.should == [:greeters]
  end

  it "adds a user" do
    put "/chat/users", :user => 129315
    last_response.should be_ok
    @rollout.get(:chat).users.should include("129315")
  end

  it "removes a user" do
    @rollout.activate_user(:chat, FakeUser.new(1))
    @rollout.activate_user(:chat, FakeUser.new(129315))

    delete "/chat/users", :user => 129315
    last_response.should be_ok
    @rollout.get(:chat).users.should == ["1"]
  end

  it "returns correct feature state for a user" do
    @rollout.activate_user(:chat, FakeUser.new(1))

    get "/chat", :user => 1233
    last_response.body.should eq("false")

    get "/chat", :user => 1
    last_response.body.should eq("true")
  end  

  it "sets the percentage" do
    put "/chat/percentage", :percentage => 22
    last_response.should be_ok
    @rollout.get(:chat).percentage.should == 22
  end

  it "deactivate_alls" do
    @rollout.activate_percentage(:chat, 100)
    @rollout.activate_group(:chat, :caretakers)
    @rollout.activate_user(:chat, FakeUser.new(129315))

    delete "/chat"
    last_response.should be_ok
    @rollout.get(:chat).to_hash.should == {:groups => [], :users => [], :percentage => 0}
  end
end
