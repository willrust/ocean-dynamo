require 'spec_helper'

class Ragadish < OceanDynamo::Table
  dynamo_schema(:uuid, :tempus, create:true, table_name_suffix: Api.basename_suffix) do
    attribute :tempus, :datetime
  end
end


describe Ragadish do

  before :each do
    Ragadish.delete_all
  end

  it "should set the keys correctly" do
    expect(Ragadish.table_hash_key).to eq :uuid
    expect(Ragadish.table_range_key).to eq :tempus
    expect(Ragadish.fields).to include :tempus
  end

  it "should be instantiatiable" do
    v = Ragadish.new
  end

  it "should be invalid if the range key is absent" do
    v = Ragadish.new()
    expect(v.valid?).to eq false
    expect(v.errors.messages).to eq({tempus: ["can't be blank"]})
  end

  it "should be persistable when both args are specified" do
    t = Time.now.utc
    v = Ragadish.create! uuid: "foo", tempus: t
    expect(v).to be_a Ragadish
    expect(v.uuid).to eq "foo"
    expect(v.tempus).to eq t
  end

  it "should assign a UUID to the hash key when unspecified" do
    v = Ragadish.create! tempus: 1.year.from_now.utc
    expect(v.uuid).to be_a String
    expect(v.uuid).not_to eq ""
  end

  it "should not persist if the range key is empty or unspecified" do
    expect { Ragadish.create! uuid: "foo", tempus: nil }.to raise_error(OceanDynamo::RecordInvalid)
    expect { Ragadish.create! uuid: "foo", tempus: false }.to raise_error(OceanDynamo::RecordInvalid)
    expect { Ragadish.create! uuid: "foo", tempus: "" }.to raise_error(OceanDynamo::RecordInvalid)
    expect { Ragadish.create! uuid: "foo", tempus: "  " }.to raise_error(OceanDynamo::RecordInvalid)
  end

  it "instances should be findable" do
    t = 1.day.ago.utc
    orig = Ragadish.create! tempus: t
    found = Ragadish.find(orig.uuid, t, consistent: true)
    expect(found.uuid).to eq orig.uuid
  end

  it "instances should be reloadable" do
    i = Ragadish.create! uuid: "quux", tempus: Time.now.utc
    i.reload
  end

end
